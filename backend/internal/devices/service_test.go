package devices

import (
	"errors"
	"testing"

	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/identity"
)

func TestDeviceAuthorization_StrictThreeDeviceQuotaAndRevocation(t *testing.T) {
	repo := database.NewMemoryRepository(3)
	idService := identity.NewService(repo)
	deviceService := NewService(repo)

	// 1. Create User
	user, err := idService.Register("@mrixk.richard", "super_secret_pwd_123", "rec-pub-key-mock", "Richard MARE")
	if err != nil {
		t.Fatalf("Failed to register user: %v", err)
	}

	// 2. Authorize Device 1 (Android)
	dev1, token1, err := deviceService.AuthorizeDevice(user.ID, "Pixel 8 Pro", "Android", "id-key-android", "dh-key-android")
	if err != nil {
		t.Fatalf("Failed to authorize Device 1: %v", err)
	}
	if dev1 == nil || token1 == "" {
		t.Fatalf("Device 1 token or object empty")
	}

	// 3. Authorize Device 2 (Windows PC)
	dev2, token2, err := deviceService.AuthorizeDevice(user.ID, "ThinkPad Workstation", "Windows", "id-key-windows", "dh-key-windows")
	if err != nil {
		t.Fatalf("Failed to authorize Device 2: %v", err)
	}
	if dev2 == nil || token2 == "" {
		t.Fatalf("Device 2 token or object empty")
	}

	// 4. Authorize Device 3 (Linux Desktop)
	dev3, token3, err := deviceService.AuthorizeDevice(user.ID, "Parrot OS Station", "Linux", "id-key-linux", "dh-key-linux")
	if err != nil {
		t.Fatalf("Failed to authorize Device 3: %v", err)
	}
	if dev3 == nil || token3 == "" {
		t.Fatalf("Device 3 token or object empty")
	}

	// Verify exactly 3 active devices
	activeList := deviceService.ListActiveDevices(user.ID)
	if len(activeList) != 3 {
		t.Fatalf("Expected 3 active devices, got %d", len(activeList))
	}

	// 5. ATTEMPT TO AUTHORIZE 4TH DEVICE (iPad / iOS) -> MUST BE REJECTED!
	dev4, token4, err := deviceService.AuthorizeDevice(user.ID, "iPad Pro", "iOS", "id-key-ios", "dh-key-ios")
	if !errors.Is(err, database.ErrMaxDevicesExceeded) {
		t.Fatalf("Security requirement failed: 4th device was NOT rejected! Result: dev=%v, token=%s, err=%v", dev4, token4, err)
	}

	// 6. Test session validation for authorized Device 1 -> SUCCESS
	validatedDev, sess, err := deviceService.ValidateSession(token1)
	if err != nil || validatedDev.ID != dev1.ID || sess.RevokedAt != nil {
		t.Fatalf("Session validation for Device 1 failed: %v", err)
	}

	// 7. Revoke Device 1
	if err := deviceService.RevokeDevice(user.ID, dev1.ID); err != nil {
		t.Fatalf("Failed to revoke Device 1: %v", err)
	}

	// Active count must now be 2
	activeListAfterRevoke := deviceService.ListActiveDevices(user.ID)
	if len(activeListAfterRevoke) != 2 {
		t.Fatalf("Expected 2 active devices after revoking dev1, got %d", len(activeListAfterRevoke))
	}

	// Session for revoked Device 1 must now be rejected
	_, _, err = deviceService.ValidateSession(token1)
	if !errors.Is(err, database.ErrSessionExpired) && !errors.Is(err, database.ErrUnauthorizedDevice) {
		t.Fatalf("Revoked device session should be invalid, got: %v", err)
	}

	// 8. Now authorize the previously rejected 4th device (now becomes the 3rd active device) -> SUCCESS
	dev4Reattempt, token4Reattempt, err := deviceService.AuthorizeDevice(user.ID, "iPad Pro", "iOS", "id-key-ios", "dh-key-ios")
	if err != nil {
		t.Fatalf("Failed to authorize replacement 3rd device after revocation: %v", err)
	}
	if dev4Reattempt == nil || token4Reattempt == "" {
		t.Fatalf("Replacement device token or object is nil")
	}

	// Active devices must be 3 again
	if len(deviceService.ListActiveDevices(user.ID)) != 3 {
		t.Fatalf("Expected 3 active devices after adding replacement, got %d", len(deviceService.ListActiveDevices(user.ID)))
	}
}
