package identity

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"mrixk.io/mrixk/backend/internal/database"
)

var (
	ErrInvalidHandle   = errors.New("invalid handle format: must be 3-30 chars, alphanumeric with optional dot or underscore")
	ErrInvalidPassword = errors.New("password must be at least 8 characters")
	ErrAuthFailed      = errors.New("authentication failed: invalid handle or credentials")
)

const (
	pbkdf2Iterations = 64000
	pbkdf2KeyLen     = 32
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

// VerifyUserPassword verifies password directly against an existing user model.
func (s *Service) VerifyUserPassword(user *database.User, password string) bool {
	if user == nil {
		return false
	}
	return verifyPassword(password, user.PasswordHash)
}

// hashPassword creates a hardened PBKDF2-HMAC-SHA256 password hash.
func hashPassword(password string) string {
	salt := make([]byte, 16)
	_, _ = rand.Read(salt)
	saltHex := hex.EncodeToString(salt)

	derived := pbkdf2SHA256([]byte(password), salt, pbkdf2Iterations, pbkdf2KeyLen)
	return fmt.Sprintf("pbkdf2_sha256$%d$%s$%s", pbkdf2Iterations, saltHex, hex.EncodeToString(derived))
}

// verifyPassword verifies password in constant time to eliminate timing side-channel attacks.
func verifyPassword(password, storedHash string) bool {
	parts := strings.Split(storedHash, "$")
	if len(parts) == 4 && parts[0] == "pbkdf2_sha256" {
		iter, err := strconv.Atoi(parts[1])
		if err != nil || iter <= 0 {
			return false
		}
		salt, err := hex.DecodeString(parts[2])
		if err != nil {
			return false
		}
		expectedHash, err := hex.DecodeString(parts[3])
		if err != nil {
			return false
		}
		computed := pbkdf2SHA256([]byte(password), salt, iter, len(expectedHash))
		return subtle.ConstantTimeCompare(computed, expectedHash) == 1
	}

	// Legacy fallback (salted SHA256) with constant-time verification
	if len(parts) == 2 {
		saltHex, expectedHex := parts[0], parts[1]
		sum := sha256.Sum256([]byte(saltHex + password))
		expectedBytes, err := hex.DecodeString(expectedHex)
		if err != nil {
			return false
		}
		return subtle.ConstantTimeCompare(sum[:], expectedBytes) == 1
	}
	return false
}

// pbkdf2SHA256 implements RFC 2898 / RFC 8018 PBKDF2 using HMAC-SHA256.
func pbkdf2SHA256(password, salt []byte, iter, keyLen int) []byte {
	prf := hmac.New(sha256.New, password)
	hashLen := prf.Size()
	numBlocks := (keyLen + hashLen - 1) / hashLen
	result := make([]byte, 0, numBlocks*hashLen)

	for block := 1; block <= numBlocks; block++ {
		prf.Reset()
		prf.Write(salt)
		buf := []byte{byte(block >> 24), byte(block >> 16), byte(block >> 8), byte(block)}
		prf.Write(buf)
		u := prf.Sum(nil)

		t := make([]byte, len(u))
		copy(t, u)

		for i := 1; i < iter; i++ {
			prf.Reset()
			prf.Write(u)
			u = prf.Sum(nil)
			for j := range t {
				t[j] ^= u[j]
			}
		}
		result = append(result, t...)
	}
	return result[:keyLen]
}
