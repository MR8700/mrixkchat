package identity

import (
	"testing"

	"mrixk.io/mrixk/backend/internal/database"
)

func TestIdentity_PBKDF2_RegistrationAndAuth(t *testing.T) {
	repo := database.NewMemoryRepository(3)
	svc := NewService(repo)

	// 1. Register user
	user, err := svc.Register("@alice", "CorrectHorseBattery99!", "rec-pub-key-1", "Alice")
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}

	if user.PasswordHash == "" {
		t.Fatalf("Password hash is empty")
	}

	// PasswordHash must not be plaintext
	if user.PasswordHash == "CorrectHorseBattery99!" {
		t.Fatalf("Password stored as plaintext!")
	}

	// 2. Successful authentication
	authUsr, err := svc.Authenticate("@alice", "CorrectHorseBattery99!")
	if err != nil || authUsr.ID != user.ID {
		t.Fatalf("Authentication should succeed with correct password, got err: %v", err)
	}

	// 3. Failed authentication with wrong password
	_, err = svc.Authenticate("@alice", "WrongPassword123!")
	if err == nil {
		t.Fatalf("Authentication should fail with wrong password!")
	}

	// 4. Verify password helper directly
	if !svc.VerifyUserPassword(user, "CorrectHorseBattery99!") {
		t.Fatalf("VerifyUserPassword returned false for correct password")
	}
	if svc.VerifyUserPassword(user, "IncorrectPassword!") {
		t.Fatalf("VerifyUserPassword returned true for incorrect password")
	}
}
