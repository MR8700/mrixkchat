package database

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

var (
	ErrUserNotFound         = errors.New("user not found")
	ErrUserAlreadyExists    = errors.New("user ID is already registered")
	ErrRecoveryCodeTaken    = errors.New("recovery code is already registered")
	ErrHandleAlreadyTaken   = errors.New("user handle is already registered")
	ErrDeviceNotFound       = errors.New("device not found")
	ErrMaxDevicesExceeded   = errors.New("device quota exceeded: maximum of 3 active devices reached")
	ErrSessionExpired       = errors.New("device session expired or revoked")
	ErrUnauthorizedDevice   = errors.New("device is not authorized")
	ErrConversationNotFound = errors.New("conversation not found")
)

type User struct {
	ID                string    `json:"id"`
	Handle            string    `json:"handle"`
	PasswordHash      string    `json:"password_hash,omitempty"`
	RecoveryPublicKey string    `json:"recovery_public_key,omitempty"`
	RecoveryCode      string    `json:"recovery_code,omitempty"`
	DisplayName       string    `json:"display_name"`
	AvatarRef         string    `json:"avatar_ref,omitempty"`
	Bio               string    `json:"bio,omitempty"`
	StatusMessage     string    `json:"status_message,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type UserPublic struct {
	ID                string    `json:"id"`
	Handle            string    `json:"handle"`
	RecoveryPublicKey string    `json:"recovery_public_key,omitempty"`
	RecoveryCode      string    `json:"recovery_code,omitempty"`
	DisplayName       string    `json:"display_name"`
	AvatarRef         string    `json:"avatar_ref,omitempty"`
	Bio               string    `json:"bio,omitempty"`
	StatusMessage     string    `json:"status_message,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// Public returns a sanitized user profile safe for API responses without password hash.
func (u *User) Public() *UserPublic {
	if u == nil {
		return nil
	}
	return &UserPublic{
		ID:                u.ID,
		Handle:            u.Handle,
		RecoveryPublicKey: u.RecoveryPublicKey,
		DisplayName:       u.DisplayName,
		AvatarRef:         u.AvatarRef,
		Bio:               u.Bio,
		StatusMessage:     u.StatusMessage,
		CreatedAt:         u.CreatedAt,
		UpdatedAt:         u.UpdatedAt,
	}
}

// PrivateProfile returns the profile INCLUDING the secret recovery code.
// Only for the account owner (registration / recovery responses). Never use in listings.
func (u *User) PrivateProfile() *UserPublic {
	p := u.Public()
	if p != nil {
		p.RecoveryCode = u.RecoveryCode
	}
	return p
}

type DeviceStatus string

const (
	DeviceStatusActive  DeviceStatus = "ACTIVE"
	DeviceStatusRevoked DeviceStatus = "REVOKED"
)

type Device struct {
	ID                     string       `json:"id"`
	UserID                 string       `json:"user_id"`
	DeviceName             string       `json:"device_name"`
	Platform               string       `json:"platform"` // Android, iOS, Windows, Linux
	IdentityPublicKey      string       `json:"identity_public_key"`
	DiffieHellmanPublicKey string       `json:"diffie_hellman_public_key"`
	Status                 DeviceStatus `json:"status"`
	LastSeenAt             time.Time    `json:"last_seen_at"`
	CreatedAt              time.Time    `json:"created_at"`
}

type DeviceSession struct {
	ID               string     `json:"id"`
	DeviceID         string     `json:"device_id"`
	SessionTokenHash string     `json:"session_token_hash,omitempty"`
	ExpiresAt        time.Time  `json:"expires_at"`
	RevokedAt        *time.Time `json:"revoked_at,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

// Tombstone records a deleted account. The handle stays reserved until ReservedUntil.
type Tombstone struct {
	UserID        string    `json:"user_id"`
	Handle        string    `json:"handle"`
	DisplayName   string    `json:"display_name"`
	DeletedAt     time.Time `json:"deleted_at"`
	ReservedUntil time.Time `json:"reserved_until"`
}

// HandleReservationTTL is how long a deleted account's handle remains reserved.
const HandleReservationTTL = 24 * time.Hour

// Persister is a durable backend (e.g. PostgreSQL) holding the serialized state.
type Persister interface {
	Save(data []byte) error
	Load() ([]byte, error)
}

type KeyPackage struct {
	ID         string    `json:"id"`
	DeviceID   string    `json:"device_id"`
	KeyType    string    `json:"key_type"`
	PublicKey  string    `json:"public_key"`
	Signature  string    `json:"signature"`
	IsConsumed bool      `json:"is_consumed"`
	CreatedAt  time.Time `json:"created_at"`
}

type Conversation struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"` // DIRECT, GROUP
	Title     string    `json:"title,omitempty"`
	CreatedBy string    `json:"created_by"`
	Members   []string  `json:"members"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type EncryptedMessageEnvelope struct {
	ID              string    `json:"id"`
	ConversationID  string    `json:"conversation_id"`
	SenderID        string    `json:"sender_id"`
	SenderDeviceID  string    `json:"sender_device_id"`
	ProtocolVersion int       `json:"protocol_version"`
	Ciphertext      string    `json:"ciphertext"` // E2EE payload, server cannot read
	IdempotencyKey  string    `json:"idempotency_key"`
	CreatedAt       time.Time `json:"created_at"`
}

type SyncEvent struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	ActorDeviceID    string    `json:"actor_device_id"`
	EventType        string    `json:"event_type"`
	EncryptedPayload string    `json:"encrypted_payload"`
	Sequence         int64     `json:"sequence"`
	CreatedAt        time.Time `json:"created_at"`
}

type SecurityEvent struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	DeviceID  string    `json:"device_id,omitempty"`
	EventType string    `json:"event_type"`
	Severity  string    `json:"severity"`
	Metadata  string    `json:"metadata"`
	CreatedAt time.Time `json:"created_at"`
}

// MemoryRepository provides a fast, thread-safe in-memory store matching PostgreSQL behavior.
type MemoryRepository struct {
	users               map[string]*User
	usersByHandle       map[string]*User
	usersByRecoveryCode map[string]*User
	devices             map[string]*Device
	sessions            map[string]*DeviceSession // sessionTokenHash -> DeviceSession
	keyPackages         map[string][]*KeyPackage  // deviceID -> list of packages
	conversations       map[string]*Conversation
	messages            map[string]*EncryptedMessageEnvelope
	syncEvents          []*SyncEvent
	securityLogs        []*SecurityEvent
	storagePath         string
	persister           Persister
	tombstones          map[string]*Tombstone // userID -> tombstone
	mu                  sync.RWMutex
	maxDevices          int
}

// SnapshotData represents the serializable state of the repository for durable persistence.
type SnapshotData struct {
	Users         map[string]*User                     `json:"users"`
	Devices       map[string]*Device                   `json:"devices"`
	Sessions      map[string]*DeviceSession            `json:"sessions,omitempty"`
	Conversations map[string]*Conversation             `json:"conversations"`
	Messages      map[string]*EncryptedMessageEnvelope `json:"messages"`
	SyncEvents    []*SyncEvent                         `json:"sync_events,omitempty"`
	Tombstones    map[string]*Tombstone                `json:"tombstones,omitempty"`
}

// SetStoragePath sets the file path for durable persistence and attempts to load existing state.
func (r *MemoryRepository) SetStoragePath(path string) error {
	r.mu.Lock()
	r.storagePath = path
	r.mu.Unlock()

	if _, err := os.Stat(path); err == nil {
		return r.LoadFromFile(path)
	}
	return nil
}

// SetPersister attaches a durable store (PostgreSQL) and loads existing state from it.
func (r *MemoryRepository) SetPersister(p Persister) error {
	data, err := p.Load()
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.persister = p
	r.mu.Unlock()
	if len(data) == 0 {
		return nil
	}
	return r.loadBytes(data)
}

func (r *MemoryRepository) saveIfConfigured() error {
	if r.persister != nil {
		data, err := r.marshalLocked()
		if err != nil {
			return err
		}
		if err := r.persister.Save(data); err != nil {
			log.Printf("[MRixk Server] ERROR persisting state to database: %v", err)
			return err
		}
	}
	if r.storagePath != "" {
		if err := r.saveToFileLocked(r.storagePath); err != nil {
			return err
		}
	}
	return nil
}

func (r *MemoryRepository) marshalLocked() ([]byte, error) {
	snap := SnapshotData{
		Users:         r.users,
		Devices:       r.devices,
		Sessions:      r.sessions,
		Conversations: r.conversations,
		Messages:      r.messages,
		SyncEvents:    r.syncEvents,
		Tombstones:    r.tombstones,
	}
	return json.Marshal(snap)
}

// SaveToFile serializes the current database state to disk atomically.
func (r *MemoryRepository) SaveToFile(path string) error {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.saveToFileLocked(path)
}

func (r *MemoryRepository) saveToFileLocked(path string) error {
	snap := SnapshotData{
		Users:         r.users,
		Devices:       r.devices,
		Sessions:      r.sessions,
		Conversations: r.conversations,
		Messages:      r.messages,
		SyncEvents:    r.syncEvents,
		Tombstones:    r.tombstones,
	}

	bytes, err := json.MarshalIndent(snap, "", "  ")
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil && filepath.Dir(path) != "." {
		return err
	}

	tmpFile := path + ".tmp"
	if err := os.WriteFile(tmpFile, bytes, 0644); err != nil {
		return err
	}
	return os.Rename(tmpFile, path)
}

// LoadFromFile restores the database state from disk.
func (r *MemoryRepository) LoadFromFile(path string) error {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return r.loadBytes(bytes)
}

func (r *MemoryRepository) loadBytes(bytes []byte) error {
	var snap SnapshotData
	if err := json.Unmarshal(bytes, &snap); err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.loadSnapshotLocked(snap)
	return nil
}

func (r *MemoryRepository) loadSnapshotLocked(snap SnapshotData) {
	if snap.Users != nil {
		r.users = snap.Users
		r.usersByHandle = make(map[string]*User)
		r.usersByRecoveryCode = make(map[string]*User)
		for _, u := range r.users {
			r.usersByHandle[u.Handle] = u
			if u.RecoveryCode != "" {
				r.usersByRecoveryCode[u.RecoveryCode] = u
			}
		}
	}
	if snap.Devices != nil {
		r.devices = snap.Devices
	}
	if snap.Sessions != nil {
		r.sessions = snap.Sessions
	}
	if snap.Conversations != nil {
		r.conversations = snap.Conversations
	}
	if snap.Messages != nil {
		r.messages = snap.Messages
	}
	if snap.SyncEvents != nil {
		r.syncEvents = snap.SyncEvents
	}
	if snap.Tombstones != nil {
		r.tombstones = snap.Tombstones
	}
}

// NewMemoryRepository instantiates the store with the specified max devices quota (3).
func NewMemoryRepository(maxDevices int) *MemoryRepository {
	if maxDevices <= 0 {
		maxDevices = 3
	}
	return &MemoryRepository{
		users:               make(map[string]*User),
		usersByHandle:       make(map[string]*User),
		usersByRecoveryCode: make(map[string]*User),
		devices:             make(map[string]*Device),
		sessions:            make(map[string]*DeviceSession),
		keyPackages:         make(map[string][]*KeyPackage),
		conversations:       make(map[string]*Conversation),
		messages:            make(map[string]*EncryptedMessageEnvelope),
		syncEvents:          make([]*SyncEvent, 0),
		tombstones:          make(map[string]*Tombstone),
		securityLogs:        make([]*SecurityEvent, 0),
		maxDevices:          maxDevices,
	}
}

// CreateUser registers a new user with unique handle.
func (r *MemoryRepository) CreateUser(u *User) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.users[u.ID]; exists {
		return ErrUserAlreadyExists
	}
	if _, exists := r.usersByHandle[u.Handle]; exists {
		return ErrHandleAlreadyTaken
	}
	if u.RecoveryCode != "" {
		if _, exists := r.usersByRecoveryCode[u.RecoveryCode]; exists {
			return ErrRecoveryCodeTaken
		}
	}
	now := time.Now()
	for _, t := range r.tombstones {
		if strings.EqualFold(t.Handle, u.Handle) && now.Before(t.ReservedUntil) {
			return ErrHandleAlreadyTaken
		}
	}
	r.users[u.ID] = u
	r.usersByHandle[u.Handle] = u
	if u.RecoveryCode != "" {
		r.usersByRecoveryCode[u.RecoveryCode] = u
	}
	if err := r.saveIfConfigured(); err != nil {
		delete(r.users, u.ID)
		delete(r.usersByHandle, u.Handle)
		if u.RecoveryCode != "" {
			delete(r.usersByRecoveryCode, u.RecoveryCode)
		}
		return err
	}
	return nil
}

// GetUserByHandle looks up a user by handle.
func (r *MemoryRepository) GetUserByHandle(handle string) (*User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	u, exists := r.usersByHandle[handle]
	if !exists {
		return nil, ErrUserNotFound
	}
	return u, nil
}

// GetUserByID looks up a user by ID.
func (r *MemoryRepository) GetUserByID(id string) (*User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	u, exists := r.users[id]
	if !exists {
		return nil, ErrUserNotFound
	}
	return u, nil
}

// GetUserByRecoveryCode looks up a user by recovery code.
func (r *MemoryRepository) GetUserByRecoveryCode(code string) (*User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	cleanCode := strings.ToUpper(strings.TrimSpace(code))
	if cleanCode == "" {
		return nil, ErrUserNotFound
	}
	for _, u := range r.users {
		if strings.ToUpper(strings.TrimSpace(u.RecoveryCode)) == cleanCode {
			return u, nil
		}
	}
	return nil, ErrUserNotFound
}

// SearchUsers searches users by handle, display name, or user ID.
func (r *MemoryRepository) SearchUsers(query string) []*UserPublic {
	r.mu.RLock()
	defer r.mu.RUnlock()

	clean := strings.ToLower(strings.TrimSpace(query))
	cleanWithoutAt := strings.TrimPrefix(clean, "@")

	var results []*UserPublic
	for _, u := range r.users {
		if clean == "" {
			results = append(results, u.Public())
			continue
		}
		uHandle := strings.ToLower(u.Handle)
		uHandleNoAt := strings.TrimPrefix(uHandle, "@")
		uName := strings.ToLower(u.DisplayName)
		uID := strings.ToLower(u.ID)

		if strings.Contains(uHandle, clean) ||
			strings.Contains(uHandleNoAt, cleanWithoutAt) ||
			strings.Contains(uName, clean) ||
			strings.Contains(uID, clean) {
			results = append(results, u.Public())
		}
	}
	return results
}

// GetAllUsers returns all users in public format.
func (r *MemoryRepository) GetAllUsers() []*UserPublic {
	return r.SearchUsers("")
}

// UpdateUser updates user profile data.
func (r *MemoryRepository) UpdateUser(u *User) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	existing, exists := r.users[u.ID]
	if !exists {
		return ErrUserNotFound
	}
	u.UpdatedAt = time.Now()
	r.users[u.ID] = u
	if u.Handle != existing.Handle {
		delete(r.usersByHandle, existing.Handle)
		r.usersByHandle[u.Handle] = u
	}
	if u.RecoveryCode != "" {
		r.usersByRecoveryCode[u.RecoveryCode] = u
	}
	if err := r.saveIfConfigured(); err != nil {
		r.users[u.ID] = existing
		r.usersByHandle[existing.Handle] = existing
		if u.Handle != existing.Handle {
			delete(r.usersByHandle, u.Handle)
		}
		if u.RecoveryCode != existing.RecoveryCode {
			delete(r.usersByRecoveryCode, u.RecoveryCode)
		}
		if existing.RecoveryCode != "" {
			r.usersByRecoveryCode[existing.RecoveryCode] = existing
		}
		return err
	}
	return nil
}

// DeleteUser permanently removes a user, revokes devices/sessions, removes them from every
// conversation (groups and direct), and leaves a tombstone reserving the handle for 24h.
func (r *MemoryRepository) DeleteUser(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	u, exists := r.users[id]
	if !exists {
		return ErrUserNotFound
	}
	before, err := r.marshalLocked()
	if err != nil {
		return err
	}
	now := time.Now()
	delete(r.users, id)
	delete(r.usersByHandle, u.Handle)
	if u.RecoveryCode != "" {
		delete(r.usersByRecoveryCode, u.RecoveryCode)
	}

	// Revoke devices and sessions
	for did, d := range r.devices {
		if d.UserID == id {
			delete(r.devices, did)
			for th, sess := range r.sessions {
				if sess.DeviceID == did {
					delete(r.sessions, th)
				}
			}
		}
	}

	// Remove from conversations; drop emptied or direct conversations
	for cid, c := range r.conversations {
		kept := make([]string, 0, len(c.Members))
		found := false
		for _, m := range c.Members {
			if m == id {
				found = true
				continue
			}
			kept = append(kept, m)
		}
		if !found {
			continue
		}
		c.Members = kept
		c.UpdatedAt = now
		for _, memberID := range kept {
			seq := int64(len(r.syncEvents) + 1)
			payload, _ := json.Marshal(map[string]string{
				"user_id": id, "handle": u.Handle, "display_name": u.DisplayName,
				"conversation_id": cid, "conversation_type": c.Type,
			})
			r.syncEvents = append(r.syncEvents, &SyncEvent{
				ID: fmt.Sprintf("sync-deleted-%s-%s-%s", id, cid, memberID), UserID: memberID,
				EventType: "USER_DELETED", EncryptedPayload: string(payload), Sequence: seq, CreatedAt: now,
			})
		}
		if len(kept) == 0 {
			delete(r.conversations, cid)
		} else if c.CreatedBy == id {
			sort.SliceStable(kept, func(i, j int) bool {
				left, right := r.users[kept[i]], r.users[kept[j]]
				if left == nil {
					return false
				}
				if right == nil {
					return true
				}
				return left.CreatedAt.Before(right.CreatedAt)
			})
			c.CreatedBy = kept[0]
		}
	}

	r.tombstones[id] = &Tombstone{
		UserID:        id,
		Handle:        u.Handle,
		DisplayName:   u.DisplayName,
		DeletedAt:     now,
		ReservedUntil: now.Add(HandleReservationTTL),
	}
	if err := r.saveIfConfigured(); err != nil {
		var snap SnapshotData
		if unmarshalErr := json.Unmarshal(before, &snap); unmarshalErr == nil {
			r.tombstones = make(map[string]*Tombstone)
			r.syncEvents = make([]*SyncEvent, 0)
			r.loadSnapshotLocked(snap)
		}
		return err
	}
	return nil
}

// AffectedUsers returns the remaining members who need a deletion notification.
func (r *MemoryRepository) AffectedUsers(id string) []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	seen := make(map[string]struct{})
	for _, c := range r.conversations {
		found := false
		for _, member := range c.Members {
			if member == id {
				found = true
				break
			}
		}
		if found {
			for _, member := range c.Members {
				if member != id {
					seen[member] = struct{}{}
				}
			}
		}
	}
	ids := make([]string, 0, len(seen))
	for member := range seen {
		ids = append(ids, member)
	}
	return ids
}

// GetTombstone returns the tombstone of a deleted account, if any.
func (r *MemoryRepository) GetTombstone(id string) (*Tombstone, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.tombstones[id]
	return t, ok
}

// UserStatuses reports for each id whether it is active or deleted (with tombstone).
func (r *MemoryRepository) UserStatuses(ids []string) (active []*UserPublic, deleted []*Tombstone) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, id := range ids {
		if u, ok := r.users[id]; ok {
			active = append(active, u.Public())
		} else if t, ok := r.tombstones[id]; ok {
			deleted = append(deleted, t)
		}
	}
	return
}

// RegisterDevice registers a device enforcing the strict 3-device limit.
func (r *MemoryRepository) RegisterDevice(d *Device) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	defer r.saveIfConfigured()

	// Count active devices for this user
	activeCount := 0
	for _, dev := range r.devices {
		if dev.UserID == d.UserID && dev.Status == DeviceStatusActive {
			activeCount++
		}
	}

	if activeCount >= r.maxDevices {
		return fmt.Errorf("%w: user %s already has %d active devices",
			ErrMaxDevicesExceeded, d.UserID, activeCount)
	}

	d.Status = DeviceStatusActive
	d.CreatedAt = time.Now()
	d.LastSeenAt = time.Now()
	r.devices[d.ID] = d
	return nil
}

// GetDevicesForUser returns all devices for a given user.
func (r *MemoryRepository) GetDevicesForUser(userID string) []*Device {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var list []*Device
	for _, dev := range r.devices {
		if dev.UserID == userID {
			list = append(list, dev)
		}
	}
	return list
}

// GetActiveDevicesForUser returns only active devices for a given user.
func (r *MemoryRepository) GetActiveDevicesForUser(userID string) []*Device {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var list []*Device
	for _, dev := range r.devices {
		if dev.UserID == userID && dev.Status == DeviceStatusActive {
			list = append(list, dev)
		}
	}
	return list
}

// RevokeDevice marks a device as REVOKED and invalidates all its sessions.
func (r *MemoryRepository) RevokeDevice(userID, deviceID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	defer r.saveIfConfigured()

	dev, exists := r.devices[deviceID]
	if !exists || dev.UserID != userID {
		return ErrDeviceNotFound
	}

	dev.Status = DeviceStatusRevoked
	now := time.Now()

	// Invalidate active sessions for this device
	for _, sess := range r.sessions {
		if sess.DeviceID == deviceID && sess.RevokedAt == nil {
			sess.RevokedAt = &now
		}
	}
	return nil
}

// CreateSession generates a cryptographic session token for an authorized device.
func (r *MemoryRepository) CreateSession(deviceID string, ttl time.Duration) (string, *DeviceSession, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	defer r.saveIfConfigured()

	dev, exists := r.devices[deviceID]
	if !exists || dev.Status != DeviceStatusActive {
		return "", nil, ErrUnauthorizedDevice
	}

	rawTokenBytes := make([]byte, 32)
	if _, err := rand.Read(rawTokenBytes); err != nil {
		return "", nil, err
	}
	rawToken := hex.EncodeToString(rawTokenBytes)

	tokenHash := HashToken(rawToken)
	session := &DeviceSession{
		ID:               fmt.Sprintf("sess-%d", time.Now().UnixNano()),
		DeviceID:         deviceID,
		SessionTokenHash: tokenHash,
		ExpiresAt:        time.Now().Add(ttl),
		CreatedAt:        time.Now(),
	}

	r.sessions[tokenHash] = session
	return rawToken, session, nil
}

// ValidateSession verifies token and returns device and session if active.
func (r *MemoryRepository) ValidateSession(rawToken string) (*Device, *DeviceSession, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	tokenHash := HashToken(rawToken)
	sess, exists := r.sessions[tokenHash]
	if !exists {
		return nil, nil, ErrSessionExpired
	}

	if sess.RevokedAt != nil || time.Now().After(sess.ExpiresAt) {
		return nil, nil, ErrSessionExpired
	}

	dev, devExists := r.devices[sess.DeviceID]
	if !devExists || dev.Status != DeviceStatusActive {
		return nil, nil, ErrUnauthorizedDevice
	}

	return dev, sess, nil
}

// CreateConversation registers a conversation.
func (r *MemoryRepository) CreateConversation(c *Conversation) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	defer r.saveIfConfigured()

	r.conversations[c.ID] = c
	return nil
}

// GetConversation returns a conversation by ID.
func (r *MemoryRepository) GetConversation(id string) (*Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	c, exists := r.conversations[id]
	if !exists {
		return nil, ErrConversationNotFound
	}
	return c, nil
}

// SaveEncryptedMessage saves an E2EE encrypted envelope.
func (r *MemoryRepository) SaveEncryptedMessage(msg *EncryptedMessageEnvelope) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	defer r.saveIfConfigured()

	if _, exists := r.conversations[msg.ConversationID]; !exists {
		return ErrConversationNotFound
	}
	r.messages[msg.ID] = msg

	// Record sync event
	seq := int64(len(r.syncEvents) + 1)
	r.syncEvents = append(r.syncEvents, &SyncEvent{
		ID:               fmt.Sprintf("sync-%s", msg.ID),
		UserID:           msg.SenderID,
		ActorDeviceID:    msg.SenderDeviceID,
		EventType:        "MESSAGE_SENT",
		EncryptedPayload: msg.Ciphertext,
		Sequence:         seq,
		CreatedAt:        time.Now(),
	})
	return nil
}

// GetSyncEvents returns events starting from a sequence cursor.
func (r *MemoryRepository) GetSyncEvents(userID string, fromSeq int64) []*SyncEvent {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var results []*SyncEvent
	for _, ev := range r.syncEvents {
		if ev.UserID == userID && ev.Sequence > fromSeq {
			results = append(results, ev)
		}
	}
	return results
}

// LogSecurityEvent records an audit entry without exposing sensitive secrets.
func (r *MemoryRepository) LogSecurityEvent(ev *SecurityEvent) {
	r.mu.Lock()
	defer r.mu.Unlock()
	ev.CreatedAt = time.Now()
	r.securityLogs = append(r.securityLogs, ev)
}

func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
