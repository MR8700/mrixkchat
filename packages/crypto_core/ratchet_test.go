package crypto_core

import (
	"bytes"
	"crypto/rand"
	"testing"
)

func TestDoubleRatchetFlow(t *testing.T) {
	// Shared secret derived from initial key agreement
	initialSharedSecret := make([]byte, 32)
	_, _ = rand.Read(initialSharedSecret)

	// Bob's prekey / initial DH pair
	bobDH, err := GenerateDHKeyPair()
	if err != nil {
		t.Fatalf("failed to generate bob DH key: %v", err)
	}

	// Initialize Alice and Bob
	alice, err := NewDoubleRatchetAlice(initialSharedSecret, bobDH.PublicKey)
	if err != nil {
		t.Fatalf("failed to initialize Alice: %v", err)
	}
	bob := NewDoubleRatchetBob(initialSharedSecret, bobDH)

	ad := []byte("conversation:conv_123")

	// 1. Alice sends message 1 to Bob
	msg1 := []byte("Bonjour Bob, message chiffré via Double Ratchet !")
	hdr1, cipher1, err := alice.Encrypt(msg1, ad)
	if err != nil {
		t.Fatalf("alice encrypt failed: %v", err)
	}

	decrypted1, err := bob.Decrypt(hdr1, cipher1, ad)
	if err != nil {
		t.Fatalf("bob decrypt failed: %v", err)
	}
	if !bytes.Equal(decrypted1, msg1) {
		t.Errorf("decrypted message mismatch: got %s, want %s", string(decrypted1), string(msg1))
	}

	// 2. Alice sends message 2 in the same chain (symmetric ratchet step)
	msg2 := []byte("Deuxième message d'Alice dans la même chaîne.")
	hdr2, cipher2, err := alice.Encrypt(msg2, ad)
	if err != nil {
		t.Fatalf("alice encrypt 2 failed: %v", err)
	}
	decrypted2, err := bob.Decrypt(hdr2, cipher2, ad)
	if err != nil {
		t.Fatalf("bob decrypt 2 failed: %v", err)
	}
	if !bytes.Equal(decrypted2, msg2) {
		t.Errorf("decrypted message 2 mismatch: got %s, want %s", string(decrypted2), string(msg2))
	}

	// 3. Bob replies (triggers DH ratchet step)
	reply1 := []byte("Réponse de Bob avec rotation de clé éphémère DH !")
	replyHdr1, replyCipher1, err := bob.Encrypt(reply1, ad)
	if err != nil {
		t.Fatalf("bob reply encrypt failed: %v", err)
	}

	decryptedReply1, err := alice.Decrypt(replyHdr1, replyCipher1, ad)
	if err != nil {
		t.Fatalf("alice decrypt reply failed: %v", err)
	}
	if !bytes.Equal(decryptedReply1, reply1) {
		t.Errorf("decrypted reply mismatch: got %s, want %s", string(decryptedReply1), string(reply1))
	}

	// 4. Alice replies back (second DH ratchet step)
	msg3 := []byte("Parfait Bob, la rotation des clés bidirectionnelle est validée.")
	hdr3, cipher3, err := alice.Encrypt(msg3, ad)
	if err != nil {
		t.Fatalf("alice encrypt 3 failed: %v", err)
	}
	decrypted3, err := bob.Decrypt(hdr3, cipher3, ad)
	if err != nil {
		t.Fatalf("bob decrypt 3 failed: %v", err)
	}
	if !bytes.Equal(decrypted3, msg3) {
		t.Errorf("decrypted message 3 mismatch: got %s, want %s", string(decrypted3), string(msg3))
	}
}
