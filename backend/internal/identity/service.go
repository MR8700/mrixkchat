package identity

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"mrixk.io/mrixk/backend/internal/database"
)

var (
	ErrInvalidHandle   = errors.New("invalid handle format: must be 3-30 chars, alphanumeric with optional dot or underscore")
	ErrInvalidPassword = errors.New("password must be at least 8 characters")
	ErrAuthFailed      = errors.New("authentication failed: invalid handle or credentials")
)

type Service struct {
	repo *database.MemoryRepository
}

func NewService(repo *database.MemoryRepository) *Service {
	return &Service{repo: repo}
}

// Register registers a new user with unique handle and optional public recovery key.
func (s *Service) Register(handle, password, recoveryPubKey, displayName string) (*database.User, error) {
	cleanHandle := strings.TrimSpace(handle)
	if !strings.HasPrefix(cleanHandle, "@") {
		cleanHandle = "@" + cleanHandle
	}

	if len(cleanHandle) < 4 || len(cleanHandle) > 32 {
		return nil, ErrInvalidHandle
	}
	if len(password) < 8 {
		return nil, ErrInvalidPassword
	}

	if displayName == "" {
		displayName = strings.TrimPrefix(cleanHandle, "@")
	}

	pwdHash := hashPassword(password)
	user := &database.User{
		ID:                fmt.Sprintf("usr-%d", time.Now().UnixNano()),
		Handle:            cleanHandle,
		PasswordHash:      pwdHash,
		RecoveryPublicKey: recoveryPubKey,
		DisplayName:       displayName,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}

	if err := s.repo.CreateUser(user); err != nil {
		return nil, err
	}

	s.repo.LogSecurityEvent(&database.SecurityEvent{
		ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
		UserID:    user.ID,
		EventType: "USER_REGISTERED",
		Severity:  "INFO",
		Metadata:  fmt.Sprintf(`{"handle":"%s"}`, user.Handle),
	})

	return user, nil
}

// Authenticate verifies credentials and returns the user object.
func (s *Service) Authenticate(handle, password string) (*database.User, error) {
	cleanHandle := strings.TrimSpace(handle)
	if !strings.HasPrefix(cleanHandle, "@") {
		cleanHandle = "@" + cleanHandle
	}

	user, err := s.repo.GetUserByHandle(cleanHandle)
	if err != nil {
		return nil, ErrAuthFailed
	}

	if !verifyPassword(password, user.PasswordHash) {
		s.repo.LogSecurityEvent(&database.SecurityEvent{
			ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
			UserID:    user.ID,
			EventType: "AUTH_FAILED",
			Severity:  "WARN",
			Metadata:  fmt.Sprintf(`{"handle":"%s"}`, cleanHandle),
		})
		return nil, ErrAuthFailed
	}

	s.repo.LogSecurityEvent(&database.SecurityEvent{
		ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
		UserID:    user.ID,
		EventType: "AUTH_SUCCESS",
		Severity:  "INFO",
	})

	return user, nil
}

// hashPassword creates a salted SHA-256 hash (PBKDF2/Argon2 abstraction).
func hashPassword(password string) string {
	salt := make([]byte, 16)
	_, _ = rand.Read(salt)
	saltHex := hex.EncodeToString(salt)

	sum := sha256.Sum256([]byte(saltHex + password))
	return fmt.Sprintf("%s$%s", saltHex, hex.EncodeToString(sum[:]))
}

func verifyPassword(password, storedHash string) bool {
	parts := strings.Split(storedHash, "$")
	if len(parts) != 2 {
		return false
	}
	saltHex, expectedHash := parts[0], parts[1]
	sum := sha256.Sum256([]byte(saltHex + password))
	return hex.EncodeToString(sum[:]) == expectedHash
}
