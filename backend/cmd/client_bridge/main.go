package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"mrixk.io/mrixk/packages/ai_runtime"
	"mrixk.io/mrixk/packages/crypto_core"
	"mrixk.io/mrixk/packages/vector_memory"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mrixk-client-bridge <sign-enroll|ratchet-encrypt|ai-query> [args...]")
		os.Exit(1)
	}
	cmd := os.Args[1]
	switch cmd {
	case "sign-enroll":
		idKey, err := crypto_core.GenerateDeviceIdentityKeyPair()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		dhKey, err := crypto_core.GenerateDHKeyPair()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		idPubHex := hex.EncodeToString(idKey.PublicKey)
		dhPubHex := hex.EncodeToString(dhKey.PublicKey.Bytes())
		msgToSign := []byte(fmt.Sprintf("%s:%s", idPubHex, dhPubHex))
		sig := idKey.Sign(msgToSign)
		out, _ := json.Marshal(map[string]string{
			"identity_public_key":       idPubHex,
			"diffie_hellman_public_key": dhPubHex,
			"key_proof_signature":       hex.EncodeToString(sig),
		})
		fmt.Println(string(out))

	case "ratchet-encrypt":
		plain := "Message E2EE Mobile <-> Linux"
		aad := "conv-e2ee-v1"
		if len(os.Args) >= 3 {
			plain = os.Args[2]
		}
		if len(os.Args) >= 4 {
			aad = os.Args[3]
		}
		secret := sha256.Sum256([]byte("mrixk-x3dh-shared-root-secret-v1"))
		bobDH, err := crypto_core.GenerateDHKeyPair()
		if err != nil {
			os.Exit(1)
		}
		alice, err := crypto_core.NewDoubleRatchetAlice(secret[:], bobDH.PublicKey)
		if err != nil {
			os.Exit(1)
		}
		bob := crypto_core.NewDoubleRatchetBob(secret[:], bobDH)

		header, ciphertext, err := alice.Encrypt([]byte(plain), []byte(aad))
		if err != nil {
			os.Exit(1)
		}
		dec, err := bob.Decrypt(header, ciphertext, []byte(aad))
		if err != nil {
			os.Exit(1)
		}
		out, _ := json.Marshal(map[string]any{
			"ciphertext_hex": hex.EncodeToString(ciphertext),
			"dh_pub_hex":     hex.EncodeToString(header.DHPublicKey),
			"n":              header.N,
			"pn":             header.PN,
			"decrypted":      string(dec),
		})
		fmt.Println(string(out))

	case "ai-query":
		userID := "user_richard"
		engine := ai_runtime.NewLocalAIEngine()
		space := engine.GetOrCreateSpace(userID)
		_ = space.AddMemory(&vector_memory.MemoryEntry{
			ID:         "mem_01",
			OwnerID:    userID,
			Content:    "Chiffrement Signal X3DH + Double Ratchet AES-256-GCM actif",
			Embedding:  vector_memory.Embedding{0.8, 0.4, 0.2, 0.1},
			Category:   "document",
			SourceType: "document",
			SourceID:   "doc_sec_01",
			Confidence: 0.95,
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		})
		results, err := space.QueryMemories(userID, "Chiffrement", vector_memory.Embedding{0.8, 0.4, 0.2, 0.1})
		if err != nil {
			os.Exit(1)
		}
		out, _ := json.Marshal(results)
		fmt.Println(string(out))
	}
}
