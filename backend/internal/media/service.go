package media

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"time"
)

var (
	ErrMediaNotFound     = errors.New("encrypted media blob not found")
	ErrIntegrityMismatch = errors.New("media payload checksum mismatch")
	ErrPayloadTooLarge   = errors.New("media exceeds maximum allowed attachment size (100MB)")
)

const MaxMediaBytes = 100 * 1024 * 1024 // 100MB

// EncryptedBlob represents an encrypted file or media asset stored temporarily on the relay.
type EncryptedBlob struct {
	ID         string    `json:"id"`
	UploaderID string    `json:"uploader_id"`
	SHA256Hash string    `json:"sha256_hash"`
	SizeBytes  int64     `json:"size_bytes"`
	MimeType   string    `json:"mime_type"`
	Data       []byte    `json:"-"`
	CreatedAt  time.Time `json:"created_at"`
	ExpiresAt  time.Time `json:"expires_at"`
}

type Service struct {
	blobs map[string]*EncryptedBlob
	mu    sync.RWMutex
}

func NewService() *Service {
	return &Service{
		blobs: make(map[string]*EncryptedBlob),
	}
}

// StoreBlob stores an encrypted media attachment with verified checksum.
func (s *Service) StoreBlob(id, uploaderID, expectedHash, mimeType string, data []byte, ttl time.Duration) (*EncryptedBlob, error) {
	if int64(len(data)) > MaxMediaBytes {
		return nil, ErrPayloadTooLarge
	}

	hasher := sha256.New()
	hasher.Write(data)
	actualHash := hex.EncodeToString(hasher.Sum(nil))

	if expectedHash != "" && actualHash != expectedHash {
		return nil, ErrIntegrityMismatch
	}

	if ttl <= 0 {
		ttl = 30 * 24 * time.Hour // Default 30 days retention on relay
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	blob := &EncryptedBlob{
		ID:         id,
		UploaderID: uploaderID,
		SHA256Hash: actualHash,
		SizeBytes:  int64(len(data)),
		MimeType:   mimeType,
		Data:       data,
		CreatedAt:  time.Now(),
		ExpiresAt:  time.Now().Add(ttl),
	}

	s.blobs[id] = blob
	return blob, nil
}

// GetBlob retrieves the encrypted payload by ID.
func (s *Service) GetBlob(id string) (*EncryptedBlob, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	blob, exists := s.blobs[id]
	if !exists {
		return nil, ErrMediaNotFound
	}

	if time.Now().After(blob.ExpiresAt) {
		return nil, fmt.Errorf("media blob expired: %w", ErrMediaNotFound)
	}

	return blob, nil
}

// DeleteBlob removes the encrypted payload from relay storage.
func (s *Service) DeleteBlob(id, requesterID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	blob, exists := s.blobs[id]
	if !exists {
		return ErrMediaNotFound
	}
	if blob.UploaderID != requesterID {
		return errors.New("unauthorized to delete this media blob")
	}

	delete(s.blobs, id)
	return nil
}
