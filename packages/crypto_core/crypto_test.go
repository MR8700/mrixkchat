package crypto_core

import (
	"bytes"
	"crypto/rand"
	"testing"
)

func TestDeviceIdentityKeyPair_SignAndVerify(t *testing.T) {
	kp, err := GenerateDeviceIdentityKeyPair()
	if err != nil {
		t.Fatalf("Failed to generate identity key pair: %v", err)
	}

	message := []byte("MRixk confidential communication payload")
	signature := kp.Sign(message)

	if !VerifySignature(kp.PublicKey, message, signature) {
		t.Fatalf("Signature verification failed on legitimate message")
	}

	// Tampered message must fail verification
	tamperedMessage := []byte("MRixk compromised communication payload")
	if VerifySignature(kp.PublicKey, tamperedMessage, signature) {
		t.Fatalf("Signature verification unexpectedly succeeded on tampered message")
	}

	// Tampered signature must fail verification
	tamperedSignature := make([]byte, len(signature))
	copy(tamperedSignature, signature)
	tamperedSignature[0] ^= 0xFF
	if VerifySignature(kp.PublicKey, message, tamperedSignature) {
		t.Fatalf("Signature verification unexpectedly succeeded on tampered signature")
	}
}

func TestDiffieHellman_SharedSecretAgreement(t *testing.T) {
	// Device A (Alice)
	aliceDH, err := GenerateDHKeyPair()
	if err != nil {
		t.Fatalf("Failed to generate Alice DH key pair: %v", err)
	}

	// Device B (Bob)
	bobDH, err := GenerateDHKeyPair()
	if err != nil {
		t.Fatalf("Failed to generate Bob DH key pair: %v", err)
	}

	// Compute shared secrets
	aliceSecret, err := aliceDH.ComputeSharedSecret(bobDH.PublicKey)
	if err != nil {
		t.Fatalf("Alice ECDH computation failed: %v", err)
	}

	bobSecret, err := bobDH.ComputeSharedSecret(aliceDH.PublicKey)
	if err != nil {
		t.Fatalf("Bob ECDH computation failed: %v", err)
	}

	if !bytes.Equal(aliceSecret, bobSecret) {
		t.Fatalf("Diffie-Hellman secrets mismatch between Alice and Bob")
	}

	// Derive 32-byte encryption key using HKDF
	salt := []byte("mrixk_protocol_v1_salt")
	info := []byte("session_key_derivation")

	aliceKey, err := DeriveKeyHKDF(aliceSecret, salt, info, 32)
	if err != nil {
		t.Fatalf("Alice HKDF derivation failed: %v", err)
	}

	bobKey, err := DeriveKeyHKDF(bobSecret, salt, info, 32)
	if err != nil {
		t.Fatalf("Bob HKDF derivation failed: %v", err)
	}

	if !bytes.Equal(aliceKey, bobKey) {
		t.Fatalf("Derived HKDF symmetric keys do not match")
	}
}

func TestAESGCM_EncryptionAndTamperResistance(t *testing.T) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatalf("Failed to generate random key: %v", err)
	}

	plaintext := []byte("Top secret personal AI and messaging note in MRixk")
	aad := []byte("sender_id:device_123")

	ciphertext, err := EncryptAESGCM(key, plaintext, aad)
	if err != nil {
		t.Fatalf("Encryption failed: %v", err)
	}

	decrypted, err := DecryptAESGCM(key, ciphertext, aad)
	if err != nil {
		t.Fatalf("Decryption failed: %v", err)
	}

	if !bytes.Equal(plaintext, decrypted) {
		t.Fatalf("Decrypted plaintext does not match original: got %s, want %s", string(decrypted), string(plaintext))
	}

	// Tampered AAD must fail
	wrongAAD := []byte("sender_id:device_attacker")
	if _, err := DecryptAESGCM(key, ciphertext, wrongAAD); err == nil {
		t.Fatalf("Decryption should fail when Additional Authenticated Data is altered")
	}

	// Tampered ciphertext must fail
	tamperedCiphertext := make([]byte, len(ciphertext))
	copy(tamperedCiphertext, ciphertext)
	tamperedCiphertext[len(tamperedCiphertext)-1] ^= 0x01
	if _, err := DecryptAESGCM(key, tamperedCiphertext, aad); err == nil {
		t.Fatalf("Decryption should fail when ciphertext or tag is modified")
	}
}

func TestPreKeyPackage_SignedAndVerified(t *testing.T) {
	idKP, err := GenerateDeviceIdentityKeyPair()
	if err != nil {
		t.Fatalf("Failed to generate identity key pair: %v", err)
	}

	deviceID := "dev-uuid-phone-001"
	pkg, _, err := CreateSignedPreKeyPackage(deviceID, idKP)
	if err != nil {
		t.Fatalf("Failed to create prekey package: %v", err)
	}

	if !VerifyPreKeyPackage(pkg, idKP.PublicKey) {
		t.Fatalf("Legitimate prekey package failed signature verification")
	}

	// Different identity public key must fail
	otherKP, _ := GenerateDeviceIdentityKeyPair()
	if VerifyPreKeyPackage(pkg, otherKP.PublicKey) {
		t.Fatalf("Prekey package verification succeeded with wrong identity public key")
	}

	// Tampered package must fail
	pkg.PublicKeyBase64 = "invalid_base64_payload"
	if VerifyPreKeyPackage(pkg, idKP.PublicKey) {
		t.Fatalf("Tampered prekey package should fail verification")
	}
}
