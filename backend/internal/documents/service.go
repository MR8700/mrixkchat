package documents

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"sync"
	"time"
)

type Role string

const (
	RoleOwner      Role = "OWNER"
	RoleAdmin      Role = "ADMIN"
	RoleModerator  Role = "MODERATOR"
	RoleMember     Role = "MEMBER"
	RoleRestricted Role = "RESTRICTED"
)

type Permission string

const (
	PermGroupManage        Permission = "group.manage"
	PermMemberInvite       Permission = "member.invite"
	PermMemberRemove       Permission = "member.remove"
	PermRoleAssign         Permission = "role.assign"
	PermModerationWarn     Permission = "moderation.warn"
	PermModerationRestrict Permission = "moderation.restrict"
	PermDocCreate          Permission = "document.create"
	PermDocEdit            Permission = "document.edit"
	PermDocPublish         Permission = "document.publish"
	PermDocFreeze          Permission = "document.freeze"
	PermDocUnfreeze        Permission = "document.unfreeze"
	PermDocRestore         Permission = "document.restore"
	PermDocDelete          Permission = "document.delete"
	PermComponentManage    Permission = "component.manage"
)

type DocumentState string

const (
	StateDraft    DocumentState = "DRAFT"
	StateActive   DocumentState = "ACTIVE"
	StateFrozen   DocumentState = "FROZEN"
	StateArchived DocumentState = "ARCHIVED"
	StateDeleted  DocumentState = "DELETED"
)

type PublishType string

const (
	PublishInPlace    PublishType = "IN_PLACE"
	PublishPostToChat PublishType = "POST_TO_CHAT"
)

// Anti-DoS resource limits enforced strictly on server
const (
	MaxDocumentSizeBytes  = 5 * 1024 * 1024 // 5 MB
	MaxComponentSizeBytes = 256 * 1024      // 256 KB
	MaxComponentsCount    = 200             // 200 components per document
)

var (
	ErrDocumentNotFound       = errors.New("document not found")
	ErrDocumentFrozen         = errors.New("document is frozen in read-only mode by an administrator")
	ErrPermissionDenied       = errors.New("permission denied: caller lacks required capability")
	ErrNotGroupMember         = errors.New("caller is not a member of this group")
	ErrConcurrentModification = errors.New("concurrent modification detected: version mismatch")
	ErrDocumentTooLarge       = errors.New("document exceeds maximum allowed size (5MB)")
	ErrComponentTooLarge      = errors.New("component exceeds maximum allowed size (256KB)")
	ErrTooManyComponents     = errors.New("maximum number of components reached (200)")
	ErrComponentReferenced    = errors.New("component is still referenced in document content")
	ErrInvalidRoleHierarchy   = errors.New("insufficient privileges to assign or modify target role")
	ErrOwnerImmutable         = errors.New("owner cannot be removed or demoted")
)

type Component struct {
	ID               string    `json:"id"`
	DocumentID       string    `json:"document_id"`
	Name             string    `json:"name"`
	ComponentType    string    `json:"component_type"`
	EncryptedPayload string    `json:"encrypted_payload"`
	Version          int       `json:"version"`
	IsActive         bool      `json:"is_active"`
	CreatedBy        string    `json:"created_by"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type GroupDocument struct {
	ID               string                `json:"id"`
	GroupID          string                `json:"group_id"`
	Title            string                `json:"title"`
	State            DocumentState         `json:"state"`
	CurrentVersion   int                   `json:"current_version"`
	EncryptedContent string                `json:"encrypted_content"`
	Components       map[string]*Component `json:"components"`
	LineSpacing      float64               `json:"line_spacing"`
	ParagraphSpacing float64               `json:"paragraph_spacing"`
	CreatedBy        string                `json:"created_by"`
	UpdatedBy        string                `json:"updated_by"`
	CreatedAt        time.Time             `json:"created_at"`
	UpdatedAt        time.Time             `json:"updated_at"`
}

type DocumentVersion struct {
	ID                          string            `json:"id"`
	DocumentID                  string            `json:"document_id"`
	VersionNum                  int               `json:"version_num"`
	EncryptedContent            string            `json:"encrypted_content"`
	EncryptedComponentsSnapshot map[string]string `json:"encrypted_components_snapshot"`
	State                       DocumentState     `json:"state"`
	PublishType                 PublishType       `json:"publish_type"`
	ModifiedBy                  string            `json:"modified_by"`
	Signature                   string            `json:"signature,omitempty"`
	CreatedAt                   time.Time         `json:"created_at"`
}

type AuditLog struct {
	ID          string    `json:"id"`
	DocumentID  string    `json:"document_id"`
	ActorID     string    `json:"actor_id"`
	Action      string    `json:"action"`
	FromVersion int       `json:"from_version"`
	ToVersion   int       `json:"to_version"`
	Metadata    string    `json:"metadata"`
	CreatedAt   time.Time `json:"created_at"`
}

type Service struct {
	mu          sync.RWMutex
	permissions map[Role]map[Permission]bool
	groupRoles  map[string]map[string]Role // groupID -> (userID -> Role)
	documents   map[string]*GroupDocument  // docID -> GroupDocument
	groupByDoc  map[string]string          // groupID -> docID (single primary doc in v1)
	versions    map[string][]*DocumentVersion
	auditLogs   map[string][]*AuditLog
}

func NewService() *Service {
	s := &Service{
		permissions: make(map[Role]map[Permission]bool),
		groupRoles:  make(map[string]map[string]Role),
		documents:   make(map[string]*GroupDocument),
		groupByDoc:  make(map[string]string),
		versions:    make(map[string][]*DocumentVersion),
		auditLogs:   make(map[string][]*AuditLog),
	}
	s.initPermissions()
	return s
}

func (s *Service) initPermissions() {
	s.permissions[RoleOwner] = map[Permission]bool{
		PermGroupManage: true, PermMemberInvite: true, PermMemberRemove: true, PermRoleAssign: true,
		PermModerationWarn: true, PermModerationRestrict: true, PermDocCreate: true, PermDocEdit: true,
		PermDocPublish: true, PermDocFreeze: true, PermDocUnfreeze: true, PermDocRestore: true,
		PermDocDelete: true, PermComponentManage: true,
	}

	s.permissions[RoleAdmin] = map[Permission]bool{
		PermGroupManage: true, PermMemberInvite: true, PermMemberRemove: true, PermRoleAssign: true,
		PermModerationWarn: true, PermModerationRestrict: true, PermDocCreate: true, PermDocEdit: true,
		PermDocPublish: true, PermDocFreeze: true, PermDocUnfreeze: true, PermDocRestore: true,
		PermDocDelete: true, PermComponentManage: true,
	}

	s.permissions[RoleModerator] = map[Permission]bool{
		PermMemberInvite: true, PermModerationWarn: true, PermModerationRestrict: true,
		PermDocCreate: true, PermDocEdit: true, PermDocPublish: true, PermDocRestore: true,
		PermComponentManage: true,
	}

	s.permissions[RoleMember] = map[Permission]bool{
		PermDocEdit: true, PermDocPublish: true, PermComponentManage: true,
	}

	s.permissions[RoleRestricted] = map[Permission]bool{}
}

func (s *Service) HasPermission(role Role, perm Permission) bool {
	perms, ok := s.permissions[role]
	if !ok {
		return false
	}
	return perms[perm]
}

func (s *Service) SetMemberRole(groupID, userID string, role Role) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.groupRoles[groupID] == nil {
		s.groupRoles[groupID] = make(map[string]Role)
	}
	s.groupRoles[groupID][userID] = role
}

func (s *Service) GetMemberRole(groupID, userID string) (Role, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	roles, ok := s.groupRoles[groupID]
	if !ok {
		return "", false
	}
	role, exists := roles[userID]
	return role, exists
}

// AssignMemberRole changes member role with strict privilege hierarchy rules
func (s *Service) AssignMemberRole(callerID, groupID, targetUserID string, newRole Role) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermRoleAssign) {
		return ErrPermissionDenied
	}

	targetRole, targetExists := s.getUserRoleLocked(groupID, targetUserID)
	if !targetExists {
		return ErrNotGroupMember
	}

	// Rule: Owner cannot be demoted or modified by non-owner
	if targetRole == RoleOwner && callerRole != RoleOwner {
		return ErrOwnerImmutable
	}

	// Rule: Non-owners cannot assign OWNER or ADMIN roles
	if (newRole == RoleOwner || newRole == RoleAdmin) && callerRole != RoleOwner {
		return ErrInvalidRoleHierarchy
	}

	// Rule: Moderator cannot promote anyone to Admin or Owner
	if callerRole == RoleModerator && (newRole == RoleAdmin || newRole == RoleOwner) {
		return ErrInvalidRoleHierarchy
	}

	s.groupRoles[groupID][targetUserID] = newRole
	return nil
}

// CreateDocument initializes a collaborative document for the group (E2EE)
func (s *Service) CreateDocument(
	callerID, groupID, title, encContent string,
	components map[string]string,
	lineSpacing, paraSpacing float64,
) (*GroupDocument, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermDocCreate) {
		return nil, ErrPermissionDenied
	}

	if len(encContent) > MaxDocumentSizeBytes {
		return nil, ErrDocumentTooLarge
	}

	if len(components) > MaxComponentsCount {
		return nil, ErrTooManyComponents
	}

	for _, payload := range components {
		if len(payload) > MaxComponentSizeBytes {
			return nil, ErrComponentTooLarge
		}
	}

	if existingDocID, exists := s.groupByDoc[groupID]; exists {
		return s.documents[existingDocID], nil
	}

	docID := generateID("doc")
	compMap := make(map[string]*Component)
	now := time.Now()

	for name, payload := range components {
		compMap[name] = &Component{
			ID:               generateID("comp"),
			DocumentID:       docID,
			Name:             name,
			ComponentType:    inferComponentType(payload),
			EncryptedPayload: payload,
			Version:          1,
			IsActive:         true,
			CreatedBy:        callerID,
			CreatedAt:        now,
			UpdatedAt:        now,
		}
	}

	if lineSpacing <= 0 {
		lineSpacing = 1.5
	}
	if paraSpacing <= 0 {
		paraSpacing = 14.0
	}

	doc := &GroupDocument{
		ID:               docID,
		GroupID:          groupID,
		Title:            title,
		State:            StateActive,
		CurrentVersion:   1,
		EncryptedContent: encContent,
		Components:       compMap,
		LineSpacing:      lineSpacing,
		ParagraphSpacing: paraSpacing,
		CreatedBy:        callerID,
		UpdatedBy:        callerID,
		CreatedAt:        now,
		UpdatedAt:        now,
	}

	s.documents[docID] = doc
	s.groupByDoc[groupID] = docID

	// Create initial immutable version snapshot
	initialVersion := &DocumentVersion{
		ID:                          generateID("ver"),
		DocumentID:                  docID,
		VersionNum:                  1,
		EncryptedContent:            encContent,
		EncryptedComponentsSnapshot: copyComponentSnapshots(components),
		State:                       StateActive,
		PublishType:                 PublishInPlace,
		ModifiedBy:                  callerID,
		CreatedAt:                   now,
	}
	s.versions[docID] = []*DocumentVersion{initialVersion}

	s.logAuditLocked(docID, callerID, "CREATED", 0, 1, fmt.Sprintf("Title: %s", title))
	return doc, nil
}

// GetDocument returns the group document verifying member access (protects against IDOR)
func (s *Service) GetDocument(callerID, groupID string) (*GroupDocument, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	_, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, ErrNotGroupMember
	}

	docID, exists := s.groupByDoc[groupID]
	if !exists {
		return nil, ErrDocumentNotFound
	}

	return s.documents[docID], nil
}

// UpdateDocument updates document content, validates anti-DoS quotas, optimistic versioning, and frozen status
func (s *Service) UpdateDocument(
	callerID, groupID, docID string,
	expectedVersion int,
	encContent string,
	components map[string]string,
	lineSpacing, paraSpacing float64,
	publishType PublishType,
) (*GroupDocument, *DocumentVersion, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, nil, ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermDocEdit) {
		return nil, nil, ErrPermissionDenied
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return nil, nil, ErrDocumentNotFound
	}

	// 1. Mandatory freeze check: server strictly rejects modifications if frozen
	if doc.State == StateFrozen {
		return nil, nil, ErrDocumentFrozen
	}

	// 2. Optimistic concurrency check
	if doc.CurrentVersion != expectedVersion {
		return nil, nil, fmt.Errorf("%w: current version is %d, expected %d",
			ErrConcurrentModification, doc.CurrentVersion, expectedVersion)
	}

	// 3. Anti-DoS payload limits
	if len(encContent) > MaxDocumentSizeBytes {
		return nil, nil, ErrDocumentTooLarge
	}
	if len(components) > MaxComponentsCount {
		return nil, nil, ErrTooManyComponents
	}
	for _, payload := range components {
		if len(payload) > MaxComponentSizeBytes {
			return nil, nil, ErrComponentTooLarge
		}
	}

	now := time.Now()
	nextVersion := doc.CurrentVersion + 1

	// Update components with version tracking
	for name, payload := range components {
		existingComp, has := doc.Components[name]
		if has {
			if existingComp.EncryptedPayload != payload {
				existingComp.EncryptedPayload = payload
				existingComp.Version++
				existingComp.UpdatedAt = now
			}
		} else {
			doc.Components[name] = &Component{
				ID:               generateID("comp"),
				DocumentID:       docID,
				Name:             name,
				ComponentType:    inferComponentType(payload),
				EncryptedPayload: payload,
				Version:          1,
				IsActive:         true,
				CreatedBy:        callerID,
				CreatedAt:        now,
				UpdatedAt:        now,
			}
		}
	}

	doc.EncryptedContent = encContent
	doc.CurrentVersion = nextVersion
	doc.UpdatedBy = callerID
	doc.UpdatedAt = now
	if lineSpacing > 0 {
		doc.LineSpacing = lineSpacing
	}
	if paraSpacing > 0 {
		doc.ParagraphSpacing = paraSpacing
	}

	// Create immutable version snapshot
	versionSnap := &DocumentVersion{
		ID:                          generateID("ver"),
		DocumentID:                  docID,
		VersionNum:                  nextVersion,
		EncryptedContent:            encContent,
		EncryptedComponentsSnapshot: copyComponentSnapshots(components),
		State:                       doc.State,
		PublishType:                 publishType,
		ModifiedBy:                  callerID,
		CreatedAt:                   now,
	}
	s.versions[docID] = append(s.versions[docID], versionSnap)

	s.logAuditLocked(docID, callerID, "EDITED", expectedVersion, nextVersion, fmt.Sprintf("Publish: %s", publishType))
	return doc, versionSnap, nil
}

// FreezeDocument locks the document into immutable read-only mode
func (s *Service) FreezeDocument(callerID, groupID, docID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermDocFreeze) {
		return ErrPermissionDenied
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return ErrDocumentNotFound
	}

	doc.State = StateFrozen
	doc.UpdatedAt = time.Now()
	doc.UpdatedBy = callerID

	s.logAuditLocked(docID, callerID, "FROZEN", doc.CurrentVersion, doc.CurrentVersion, "Document frozen by administrator")
	return nil
}

// UnfreezeDocument unlocks the document
func (s *Service) UnfreezeDocument(callerID, groupID, docID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermDocUnfreeze) {
		return ErrPermissionDenied
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return ErrDocumentNotFound
	}

	doc.State = StateActive
	doc.UpdatedAt = time.Now()
	doc.UpdatedBy = callerID

	s.logAuditLocked(docID, callerID, "UNFROZEN", doc.CurrentVersion, doc.CurrentVersion, "Document unfrozen by administrator")
	return nil
}

// RestoreVersion restores document state to a previous immutable version snapshot
func (s *Service) RestoreVersion(callerID, groupID, docID string, targetVersion int) (*GroupDocument, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermDocRestore) {
		return nil, ErrPermissionDenied
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return nil, ErrDocumentNotFound
	}

	if doc.State == StateFrozen {
		return nil, ErrDocumentFrozen
	}

	var targetSnap *DocumentVersion
	for _, v := range s.versions[docID] {
		if v.VersionNum == targetVersion {
			targetSnap = v
			break
		}
	}
	if targetSnap == nil {
		return nil, fmt.Errorf("target version %d not found in history", targetVersion)
	}

	now := time.Now()
	nextVersion := doc.CurrentVersion + 1

	// Restore components snapshot
	restoredComps := make(map[string]*Component)
	for name, payload := range targetSnap.EncryptedComponentsSnapshot {
		restoredComps[name] = &Component{
			ID:               generateID("comp"),
			DocumentID:       docID,
			Name:             name,
			ComponentType:    inferComponentType(payload),
			EncryptedPayload: payload,
			Version:          1,
			IsActive:         true,
			CreatedBy:        callerID,
			CreatedAt:        now,
			UpdatedAt:        now,
		}
	}

	fromVersion := doc.CurrentVersion
	doc.EncryptedContent = targetSnap.EncryptedContent
	doc.Components = restoredComps
	doc.CurrentVersion = nextVersion
	doc.UpdatedBy = callerID
	doc.UpdatedAt = now

	// Append restored version as new immutable version
	newVersionSnap := &DocumentVersion{
		ID:                          generateID("ver"),
		DocumentID:                  docID,
		VersionNum:                  nextVersion,
		EncryptedContent:            targetSnap.EncryptedContent,
		EncryptedComponentsSnapshot: copyComponentSnapshots(targetSnap.EncryptedComponentsSnapshot),
		State:                       StateActive,
		PublishType:                 PublishInPlace,
		ModifiedBy:                  callerID,
		CreatedAt:                   now,
	}
	s.versions[docID] = append(s.versions[docID], newVersionSnap)

	s.logAuditLocked(docID, callerID, "RESTORED", fromVersion, nextVersion, fmt.Sprintf("Restored from version %d", targetVersion))
	return doc, nil
}

// DeleteComponent safeguards against deleting a component that is still referenced in the document text
func (s *Service) DeleteComponent(callerID, groupID, docID, compName string, force bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return ErrNotGroupMember
	}

	if !s.HasPermission(callerRole, PermComponentManage) {
		return ErrPermissionDenied
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return ErrDocumentNotFound
	}

	if doc.State == StateFrozen {
		return ErrDocumentFrozen
	}

	// Check if referenced as {{compName}}
	pattern := fmt.Sprintf(`\{\{\s*%s\s*\}\}`, regexp.QuoteMeta(compName))
	re := regexp.MustCompile(pattern)
	if re.MatchString(doc.EncryptedContent) && !force {
		return ErrComponentReferenced
	}

	delete(doc.Components, compName)
	doc.UpdatedAt = time.Now()
	doc.UpdatedBy = callerID

	s.logAuditLocked(docID, callerID, "COMPONENT_DELETED", doc.CurrentVersion, doc.CurrentVersion, fmt.Sprintf("Deleted: %s", compName))
	return nil
}

// GetVersions returns immutable version history
func (s *Service) GetVersions(callerID, groupID, docID string) ([]*DocumentVersion, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	_, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, ErrNotGroupMember
	}

	doc, exists := s.documents[docID]
	if !exists || doc.GroupID != groupID {
		return nil, ErrDocumentNotFound
	}

	return s.versions[docID], nil
}

// GetAuditLogs returns the tamper-evident audit history
func (s *Service) GetAuditLogs(callerID, groupID, docID string) ([]*AuditLog, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	callerRole, isMember := s.getUserRoleLocked(groupID, callerID)
	if !isMember {
		return nil, ErrNotGroupMember
	}

	if callerRole != RoleOwner && callerRole != RoleAdmin {
		return nil, ErrPermissionDenied
	}

	return s.auditLogs[docID], nil
}

func (s *Service) getUserRoleLocked(groupID, userID string) (Role, bool) {
	roles, ok := s.groupRoles[groupID]
	if !ok {
		return "", false
	}
	role, exists := roles[userID]
	return role, exists
}

func (s *Service) logAuditLocked(docID, actorID, action string, fromVer, toVer int, meta string) {
	entry := &AuditLog{
		ID:          generateID("audit"),
		DocumentID:  docID,
		ActorID:     actorID,
		Action:      action,
		FromVersion: fromVer,
		ToVersion:   toVer,
		Metadata:    meta,
		CreatedAt:   time.Now(),
	}
	s.auditLogs[docID] = append(s.auditLogs[docID], entry)
}

func generateID(prefix string) string {
	bytes := make([]byte, 8)
	_, _ = rand.Read(bytes)
	return fmt.Sprintf("%s_%s", prefix, hex.EncodeToString(bytes))
}

func inferComponentType(payload string) string {
	if regexp.MustCompile(`(?i)<table`).MatchString(payload) {
		return "TABLE"
	}
	if regexp.MustCompile(`(?i)<math`).MatchString(payload) {
		return "MATH"
	}
	if regexp.MustCompile(`(?i)<diagram`).MatchString(payload) {
		return "DIAGRAM"
	}
	if regexp.MustCompile(`(?i)<graph`).MatchString(payload) {
		return "GRAPH"
	}
	return "CUSTOM"
}

func copyComponentSnapshots(m map[string]string) map[string]string {
	res := make(map[string]string, len(m))
	for k, v := range m {
		res[k] = v
	}
	return res
}
