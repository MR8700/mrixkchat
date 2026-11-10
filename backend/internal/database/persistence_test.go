package database

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestDatabase_DurablePersistenceAndSessionRecovery(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "mrixk_db_test_*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	dbFile := filepath.Join(tmpDir, "state.json")

	// 1. Initialize first repo instance with storage path
	repo1 := NewMemoryRepository(3)
	if err := repo1.SetStoragePath(dbFile); err != nil {
		t.Fatalf("SetStoragePath failed: %v", err)
	}

	// 2. Insert User
	user := &User{
		ID:           "usr-101",
		Handle:       "@bob",
		PasswordHash: "pbkdf2_sha256$64000$salthex$hashhex",
		DisplayName:  "Bob",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	if err := repo1.CreateUser(user); err != nil {
		t.Fatalf("CreateUser failed: %v", err)
	}

	// 3. Register Device
	dev := &Device{
		ID:                     "dev-101",
		UserID:                 user.ID,
		DeviceName:             "Bob Laptop",
		Platform:               "Linux",
		IdentityPublicKey:     "bob-id-key",
		DiffieHellmanPublicKey: "bob-dh-key",
		Status:                 DeviceStatusActive,
		CreatedAt:              time.Now(),
		LastSeenAt:             time.Now(),
	}
	if err := repo1.RegisterDevice(dev); err != nil {
		t.Fatalf("RegisterDevice failed: %v", err)
	}

	// 4. Create Session
	rawToken, sess, err := repo1.CreateSession(dev.ID, 24*time.Hour)
	if err != nil || rawToken == "" || sess == nil {
		t.Fatalf("CreateSession failed: %v", err)
	}

	// 5. Create Conversation and Store Encrypted Message
	conv := &Conversation{
		ID:        "conv-101",
		Type:      "DIRECT",
		Title:     "Private Chat",
		CreatedBy: user.ID,
		Members:   []string{user.ID},
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if err := repo1.CreateConversation(conv); err != nil {
		t.Fatalf("CreateConversation failed: %v", err)
	}

	msg := &EncryptedMessageEnvelope{
		ID:              "msg-101",
		ConversationID:  conv.ID,
		SenderID:        user.ID,
		SenderDeviceID:  dev.ID,
		ProtocolVersion: 1,
		Ciphertext:      "CIPHERTEXT_AES_GCM_ENVELOPE",
		IdempotencyKey:  "idem-101",
		CreatedAt:       time.Now(),
	}
	if err := repo1.SaveEncryptedMessage(msg); err != nil {
		t.Fatalf("SaveEncryptedMessage failed: %v", err)
	}

	// 6. Simulate Server Shutdown / Restart: instantiate a brand new repo loading the file
	repo2 := NewMemoryRepository(3)
	if err := repo2.LoadFromFile(dbFile); err != nil {
		t.Fatalf("LoadFromFile failed on restored repo: %v", err)
	}

	// Verify User restored with intact PasswordHash
	restoredUser, err := repo2.GetUserByID(user.ID)
	if err != nil || restoredUser == nil {
		t.Fatalf("Restored user not found: %v", err)
	}
	if restoredUser.PasswordHash != user.PasswordHash {
		t.Fatalf("PasswordHash was lost during persistence! expected %s, got %s", user.PasswordHash, restoredUser.PasswordHash)
	}

	// Verify Device restored
	devices := repo2.GetDevicesForUser(user.ID)
	if len(devices) != 1 || devices[0].ID != dev.ID {
		t.Fatalf("Restored devices mismatch: %v", devices)
	}

	// Verify Session restored and valid
	valDev, valSess, err := repo2.ValidateSession(rawToken)
	if err != nil || valDev == nil || valSess == nil {
		t.Fatalf("Session token validation failed after restart: %v", err)
	}
	if valDev.ID != dev.ID {
		t.Fatalf("Validated device ID mismatch: expected %s, got %s", dev.ID, valDev.ID)
	}

	// Verify Conversation restored
	restoredConv, err := repo2.GetConversation("conv-101")
	if err != nil || restoredConv == nil || restoredConv.Title != conv.Title {
		t.Fatalf("Restored conversation mismatch: %v", restoredConv)
	}
}
