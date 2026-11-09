package crypto_core

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

var (
	ErrInvalidSignature   = errors.New("invalid digital signature")
	ErrDecryptionFailed   = errors.New("authenticated decryption failed")
	ErrInvalidKeyLength   = errors.New("invalid cryptographic key length")
	ErrReplayDetected     = errors.New("replay attack detected: message nonce already processed")
	ErrInvalidPreKey      = errors.New("invalid or tampered prekey package")
)

// DeviceIdentityKeyPair holds a device's permanent Ed25519 identity key pair.
// Private keys NEVER leave the device.
type DeviceIdentityKeyPair struct {
	PublicKey  ed25519.PublicKey
	PrivateKey ed25519.PrivateKey
}

// GenerateDeviceIdentityKeyPair generates a new independent Ed25519 key pair for a device.
func GenerateDeviceIdentityKeyPair() (*DeviceIdentityKeyPair, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate identity key pair: %w", err)
	}
	return &DeviceIdentityKeyPair{
		PublicKey:  pub,
		PrivateKey: priv,
	}, nil
}

// Sign signs a message using the device's private identity key.
func (kp *DeviceIdentityKeyPair) Sign(message []byte) []byte {
	return ed25519.Sign(kp.PrivateKey, message)
}

// VerifySignature verifies an Ed25519 signature against the given public key.
func VerifySignature(pubKey ed25519.PublicKey, message, signature []byte) bool {
	return ed25519.Verify(pubKey, message, signature)
}

// DiffieHellmanKeyPair holds an X25519 ECDH key pair for session agreements.
type DiffieHellmanKeyPair struct {
	PrivateKey *ecdh.PrivateKey
	PublicKey  *ecdh.PublicKey
}

// GenerateDHKeyPair generates a new X25519 key pair.
func GenerateDHKeyPair() (*DiffieHellmanKeyPair, error) {
	priv, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate X25519 key pair: %w", err)
	}
	return &DiffieHellmanKeyPair{
		PrivateKey: priv,
		PublicKey:  priv.PublicKey(),
	}, nil
}

// ComputeSharedSecret derives an ECDH shared secret between local private key and remote public key.
func (kp *DiffieHellmanKeyPair) ComputeSharedSecret(peerPubKey *ecdh.PublicKey) ([]byte, error) {
	return kp.PrivateKey.ECDH(peerPubKey)
}

// DeriveKeyHKDF performs HKDF-Extract and HKDF-Expand with SHA-256 to derive a symmetric key.
func DeriveKeyHKDF(secret, salt, info []byte, length int) ([]byte, error) {
	if len(salt) == 0 {
		salt = make([]byte, sha256.Size)
	}
	// HKDF-Extract: PRK = HMAC-Hash(salt, IKM)
	h := hmac.New(sha256.New, salt)
	h.Write(secret)
	prk := h.Sum(nil)

	// HKDF-Expand: OKM = HMAC-Hash(PRK, info || 0x01)
	out := make([]byte, 0, length)
	var prev []byte
	iteration := byte(1)

	for len(out) < length {
		hExp := hmac.New(sha256.New, prk)
		if len(prev) > 0 {
			hExp.Write(prev)
		}
		hExp.Write(info)
		hExp.Write([]byte{iteration})
		prev = hExp.Sum(nil)

		toCopy := len(prev)
		if len(out)+toCopy > length {
			toCopy = length - len(out)
		}
		out = append(out, prev[:toCopy]...)
		iteration++
	}

	return out, nil
}

// EncryptAESGCM encrypts plaintext using AES-256-GCM with a random 12-byte nonce.
// Returns nonce + ciphertext + auth tag.
func EncryptAESGCM(key, plaintext, additionalData []byte) ([]byte, error) {
	if len(key) != 32 {
		return nil, ErrInvalidKeyLength
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	ciphertext := gcm.Seal(nonce, nonce, plaintext, additionalData)
	return ciphertext, nil
}

// DecryptAESGCM decrypts AES-256-GCM ciphertext (nonce prepended) and verifies auth tag.
func DecryptAESGCM(key, ciphertextWithNonce, additionalData []byte) ([]byte, error) {
	if len(key) != 32 {
		return nil, ErrInvalidKeyLength
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonceSize := gcm.NonceSize()
	if len(ciphertextWithNonce) < nonceSize {
		return nil, ErrDecryptionFailed
	}
	nonce := ciphertextWithNonce[:nonceSize]
	ciphertext := ciphertextWithNonce[nonceSize:]

	plaintext, err := gcm.Open(nil, nonce, ciphertext, additionalData)
	if err != nil {
		return nil, ErrDecryptionFailed
	}
	return plaintext, nil
}

// PreKeyPackage represents a signed pre-key published to the server for asynchronous session initialization.
type PreKeyPackage struct {
	DeviceID        string `json:"device_id"`
	KeyType         string `json:"key_type"`
	PublicKeyBase64 string `json:"public_key"`
	SignatureBase64 string `json:"signature"`
}

// CreateSignedPreKeyPackage generates a pre-key, signs it with the device identity key, and returns the package.
func CreateSignedPreKeyPackage(deviceID string, idKP *DeviceIdentityKeyPair) (*PreKeyPackage, *DiffieHellmanKeyPair, error) {
	dhKey, err := GenerateDHKeyPair()
	if err != nil {
		return nil, nil, err
	}
	pubBytes := dhKey.PublicKey.Bytes()
	sig := idKP.Sign(pubBytes)

	pkg := &PreKeyPackage{
		DeviceID:        deviceID,
		KeyType:         "signed_prekey",
		PublicKeyBase64: base64.StdEncoding.EncodeToString(pubBytes),
		SignatureBase64: base64.StdEncoding.EncodeToString(sig),
	}
	return pkg, dhKey, nil
}

// VerifyPreKeyPackage verifies that a pre-key package was legitimately signed by the device's public identity key.
func VerifyPreKeyPackage(pkg *PreKeyPackage, identityPubKey ed25519.PublicKey) bool {
	pubBytes, err := base64.StdEncoding.DecodeString(pkg.PublicKeyBase64)
	if err != nil {
		return false
	}
	sigBytes, err := base64.StdEncoding.DecodeString(pkg.SignatureBase64)
	if err != nil {
		return false
	}
	return VerifySignature(identityPubKey, pubBytes, sigBytes)
}

// HashSHA256 computes a standard SHA-256 checksum (hex/bytes).
func HashSHA256(data []byte) [32]byte {
	return sha256.Sum256(data)
}
