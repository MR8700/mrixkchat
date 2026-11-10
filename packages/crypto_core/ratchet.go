package crypto_core

import (
	"crypto/ecdh"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
)

var (
	ErrRatchetKeyNotFound  = errors.New("ratchet skipped message key not found")
	ErrMaxSkipLimitReached = errors.New("max out-of-order message limit exceeded")
)

const (
	MaxSkipMessages = 1000
)

// MessageHeader contains ephemeral DH public key and sequence counters for Double Ratchet.
type MessageHeader struct {
	DHPublicKey []byte `json:"dh"`
	PN          int    `json:"pn"` // Previous chain length
	N           int    `json:"n"`  // Message index in current chain
}

// DoubleRatchetSession holds the complete Double Ratchet state between two endpoints.
type DoubleRatchetSession struct {
	LocalDH    *DiffieHellmanKeyPair
	RemoteDH   *ecdh.PublicKey
	RootKey    []byte
	SendCK     []byte
	RecvCK     []byte
	Ns         int
	Nr         int
	PN         int
	SkippedMK  map[string][]byte // "DHPublicKeyHex:Index" -> MessageKey
}

// NewDoubleRatchetAlice initializes Alice's session (initiator) with a shared secret from X3DH.
func NewDoubleRatchetAlice(sharedKey []byte, bobDHPublicKey *ecdh.PublicKey) (*DoubleRatchetSession, error) {
	aliceDH, err := GenerateDHKeyPair()
	if err != nil {
		return nil, err
	}

	dhSecret, err := aliceDH.ComputeSharedSecret(bobDHPublicKey)
	if err != nil {
		return nil, fmt.Errorf("alice initial DH failed: %w", err)
	}

	rk, sendCK, err := kdfRK(sharedKey, dhSecret)
	if err != nil {
		return nil, err
	}

	return &DoubleRatchetSession{
		LocalDH:   aliceDH,
		RemoteDH:  bobDHPublicKey,
		RootKey:   rk,
		SendCK:    sendCK,
		RecvCK:    nil,
		Ns:        0,
		Nr:        0,
		PN:        0,
		SkippedMK: make(map[string][]byte),
	}, nil
}

// NewDoubleRatchetBob initializes Bob's session (receiver).
func NewDoubleRatchetBob(sharedKey []byte, bobDHKeyPair *DiffieHellmanKeyPair) *DoubleRatchetSession {
	return &DoubleRatchetSession{
		LocalDH:   bobDHKeyPair,
		RemoteDH:  nil,
		RootKey:   sharedKey,
		SendCK:    nil,
		RecvCK:    nil,
		Ns:        0,
		Nr:        0,
		PN:        0,
		SkippedMK: make(map[string][]byte),
	}
}

// Encrypt encrypts a message using the current sending chain and advances the send ratchet.
func (s *DoubleRatchetSession) Encrypt(plaintext, ad []byte) (*MessageHeader, []byte, error) {
	if s.SendCK == nil {
		return nil, nil, errors.New("sending chain not initialized")
	}

	nextCK, mk, err := kdfCK(s.SendCK)
	if err != nil {
		return nil, nil, err
	}
	s.SendCK = nextCK

	header := &MessageHeader{
		DHPublicKey: s.LocalDH.PublicKey.Bytes(),
		PN:          s.PN,
		N:           s.Ns,
	}
	s.Ns++

	// Associated data includes header bytes to prevent tampering
	headerBytes := []byte(fmt.Sprintf("%s:%d:%d", hex.EncodeToString(header.DHPublicKey), header.PN, header.N))
	fullAD := append(ad, headerBytes...)

	ciphertext, err := EncryptAESGCM(mk, plaintext, fullAD)
	if err != nil {
		return nil, nil, err
	}

	return header, ciphertext, nil
}

// Decrypt decrypts an incoming message and updates the DH/symmetric ratchet accordingly.
func (s *DoubleRatchetSession) Decrypt(header *MessageHeader, ciphertext, ad []byte) ([]byte, error) {
	headerBytes := []byte(fmt.Sprintf("%s:%d:%d", hex.EncodeToString(header.DHPublicKey), header.PN, header.N))
	fullAD := append(ad, headerBytes...)

	skipKey := fmt.Sprintf("%s:%d", hex.EncodeToString(header.DHPublicKey), header.N)
	if mk, exists := s.SkippedMK[skipKey]; exists {
		delete(s.SkippedMK, skipKey)
		return DecryptAESGCM(mk, ciphertext, fullAD)
	}

	remotePubKey, err := ecdh.X25519().NewPublicKey(header.DHPublicKey)
	if err != nil {
		return nil, fmt.Errorf("invalid sender DH key: %w", err)
	}

	// Check if this is a new DH step from the peer
	if s.RemoteDH == nil || !s.RemoteDH.Equal(remotePubKey) {
		if err := s.skipMessageKeys(header.PN); err != nil {
			return nil, err
		}
		if err := s.dhRatchetStep(remotePubKey); err != nil {
			return nil, err
		}
	}

	if err := s.skipMessageKeys(header.N); err != nil {
		return nil, err
	}

	nextCK, mk, err := kdfCK(s.RecvCK)
	if err != nil {
		return nil, err
	}
	s.RecvCK = nextCK
	s.Nr++

	return DecryptAESGCM(mk, ciphertext, fullAD)
}

func (s *DoubleRatchetSession) dhRatchetStep(newRemoteDH *ecdh.PublicKey) error {
	s.PN = s.Ns
	s.Ns = 0
	s.Nr = 0
	s.RemoteDH = newRemoteDH

	dhSecret, err := s.LocalDH.ComputeSharedSecret(s.RemoteDH)
	if err != nil {
		return err
	}
	rk, recvCK, err := kdfRK(s.RootKey, dhSecret)
	if err != nil {
		return err
	}
	s.RootKey = rk
	s.RecvCK = recvCK

	newLocalDH, err := GenerateDHKeyPair()
	if err != nil {
		return err
	}
	s.LocalDH = newLocalDH

	dhSecret2, err := s.LocalDH.ComputeSharedSecret(s.RemoteDH)
	if err != nil {
		return err
	}
	rk2, sendCK, err := kdfRK(s.RootKey, dhSecret2)
	if err != nil {
		return err
	}
	s.RootKey = rk2
	s.SendCK = sendCK

	return nil
}

func (s *DoubleRatchetSession) skipMessageKeys(until int) error {
	if s.RecvCK == nil {
		return nil
	}
	if s.Nr+MaxSkipMessages < until {
		return ErrMaxSkipLimitReached
	}
	for s.Nr < until {
		nextCK, mk, err := kdfCK(s.RecvCK)
		if err != nil {
			return err
		}
		s.RecvCK = nextCK
		skipKey := fmt.Sprintf("%s:%d", hex.EncodeToString(s.RemoteDH.Bytes()), s.Nr)
		s.SkippedMK[skipKey] = mk
		s.Nr++
	}
	return nil
}

// kdfRK derives (RootKey, ChainKey) from RootKey and DH shared secret.
func kdfRK(rk, dhSecret []byte) ([]byte, []byte, error) {
	derived, err := DeriveKeyHKDF(dhSecret, rk, []byte("MRixk-DoubleRatchet-RootKDF"), 64)
	if err != nil {
		return nil, nil, err
	}
	return derived[:32], derived[32:64], nil
}

// kdfCK advances the chain key and outputs a message key.
func kdfCK(ck []byte) ([]byte, []byte, error) {
	// nextCK = HMAC-SHA256(ck, 0x01)
	h1 := hmac.New(sha256.New, ck)
	h1.Write([]byte{0x01})
	nextCK := h1.Sum(nil)

	// messageKey = HMAC-SHA256(ck, 0x02)
	h2 := hmac.New(sha256.New, ck)
	h2.Write([]byte{0x02})
	mk := h2.Sum(nil)

	return nextCK, mk, nil
}
