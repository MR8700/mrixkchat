package contacts

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"sync"
	"time"
)

var (
	ErrContactNotFound = errors.New("contact not found in directory")
)

type ContactEntry struct {
	UserID            string    `json:"user_id"`
	Handle            string    `json:"handle"`
	DisplayName       string    `json:"display_name"`
	AvatarURL         string    `json:"avatar_url"`
	IdentityPublicKey string    `json:"identity_public_key"`
	IsVerified        bool      `json:"is_verified"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type Service struct {
	directory map[string]*ContactEntry // UserID -> Entry
	byHandle  map[string]*ContactEntry
	mu        sync.RWMutex
}

func NewService() *Service {
	return &Service{
		directory: make(map[string]*ContactEntry),
		byHandle:  make(map[string]*ContactEntry),
	}
}

func (s *Service) UpsertContact(entry *ContactEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()

	entry.UpdatedAt = time.Now()
	s.directory[entry.UserID] = entry
	s.byHandle[entry.Handle] = entry
}

func (s *Service) GetContact(userID string) (*ContactEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	entry, exists := s.directory[userID]
	if !exists {
		return nil, ErrContactNotFound
	}
	return entry, nil
}

func (s *Service) Search(query string) []*ContactEntry {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var results []*ContactEntry
	for _, entry := range s.directory {
		results = append(results, entry)
	}
	return results
}

// ComputeSafetyNumber derives a standardized 60-digit safety fingerprint between two identity keys.
func ComputeSafetyNumber(userAKey, userBKey string) string {
	var first, second string
	if userAKey < userBKey {
		first, second = userAKey, userBKey
	} else {
		first, second = userBKey, userAKey
	}

	h := sha256.New()
	h.Write([]byte(first))
	h.Write([]byte(second))
	hashBytes := h.Sum(nil)

	// Format into 12 blocks of 5 digits
	var digits string
	for i := 0; i < 15; i++ {
		val := int(hashBytes[i%len(hashBytes)]) * 397
		digits += fmt.Sprintf("%04d", val%10000)
	}
	if len(digits) > 60 {
		digits = digits[:60]
	}

	var formatted string
	for i := 0; i < len(digits); i += 5 {
		end := i + 5
		if end > len(digits) {
			end = len(digits)
		}
		if formatted != "" {
			if i%20 == 0 {
				formatted += "\n"
			} else {
				formatted += " "
			}
		}
		formatted += digits[i:end]
	}

	return formatted
}
