package devices

import (
	"errors"
	"fmt"
	"time"

	"mrixk.io/mrixk/backend/internal/database"
)

var (
	ErrInvalidPlatform  = errors.New("invalid platform: must be Android, iOS, Windows, or Linux")
	ErrMissingKey        = errors.New("identity public key and diffie hellman public key are required")
)

type Service struct {
	repo *database.MemoryRepository
}

func NewService(repo *database.MemoryRepository) *Service {
	return &Service{repo: repo}
}

// AuthorizeDevice registers an independent device for the user.
// Enforces: Max 3 devices. A 4th device will be explicitly rejected.
func (s *Service) AuthorizeDevice(userID, deviceName, platform, identityPubKey, dhPubKey string) (*database.Device, string, error) {
	if identityPubKey == "" || dhPubKey == "" {
		return nil, "", ErrMissingKey
	}

	validPlatform := false
	for _, p := range []string{"Android", "iOS", "Windows", "Linux"} {
		if platform == p {
			validPlatform = true
			break
		}
	}
	if !validPlatform {
		return nil, "", ErrInvalidPlatform
	}

	device := &database.Device{
		ID:                    fmt.Sprintf("dev-%d", time.Now().UnixNano()),
		UserID:                userID,
		DeviceName:            deviceName,
		Platform:              platform,
		IdentityPublicKey:     identityPubKey,
		DiffieHellmanPublicKey: dhPubKey,
		Status:                database.DeviceStatusActive,
		CreatedAt:             time.Now(),
		LastSeenAt:            time.Now(),
	}

	// Register in repository (will enforce max 3 active devices quota)
	if err := s.repo.RegisterDevice(device); err != nil {
		s.repo.LogSecurityEvent(&database.SecurityEvent{
			ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
			UserID:    userID,
			EventType: "DEVICE_AUTHORIZATION_REJECTED",
			Severity:  "WARN",
			Metadata:  fmt.Sprintf(`{"reason":"%s","attempted_device":"%s"}`, err.Error(), deviceName),
		})
		return nil, "", err
	}

	// Create session token valid for 30 days
	sessionTTL := 30 * 24 * time.Hour
	rawToken, _, err := s.repo.CreateSession(device.ID, sessionTTL)
	if err != nil {
		return nil, "", err
	}

	s.repo.LogSecurityEvent(&database.SecurityEvent{
		ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
		UserID:    userID,
		DeviceID:  device.ID,
		EventType: "DEVICE_AUTHORIZED",
		Severity:  "INFO",
		Metadata:  fmt.Sprintf(`{"platform":"%s","device_name":"%s"}`, platform, deviceName),
	})

	return device, rawToken, nil
}

// ListDevices returns all devices for a user.
func (s *Service) ListDevices(userID string) []*database.Device {
	return s.repo.GetDevicesForUser(userID)
}

// ListActiveDevices returns only active devices for a user.
func (s *Service) ListActiveDevices(userID string) []*database.Device {
	return s.repo.GetActiveDevicesForUser(userID)
}

// RevokeDevice revokes an authorized device, freeing the quota slot and invalidating its sessions.
func (s *Service) RevokeDevice(userID, deviceID string) error {
	if err := s.repo.RevokeDevice(userID, deviceID); err != nil {
		return err
	}

	s.repo.LogSecurityEvent(&database.SecurityEvent{
		ID:        fmt.Sprintf("sec-%d", time.Now().UnixNano()),
		UserID:    userID,
		DeviceID:  deviceID,
		EventType: "DEVICE_REVOKED",
		Severity:  "INFO",
	})
	return nil
}

// ValidateSession verifies session token.
func (s *Service) ValidateSession(rawToken string) (*database.Device, *database.DeviceSession, error) {
	return s.repo.ValidateSession(rawToken)
}
