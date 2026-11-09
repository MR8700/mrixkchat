package messaging

import (
	"errors"
	"fmt"
	"time"

	"mrixk.io/mrixk/backend/internal/database"
)

var (
	ErrEmptyCiphertext       = errors.New("ciphertext payload cannot be empty")
	ErrSenderNotMember       = errors.New("sender is not a member of the conversation")
	ErrDuplicateIdempotency  = errors.New("duplicate message: idempotency key already processed")
)

type Service struct {
	repo *database.MemoryRepository
}

func NewService(repo *database.MemoryRepository) *Service {
	return &Service{repo: repo}
}

// CreateConversation creates a direct or group conversation.
func (s *Service) CreateConversation(convType, title, createdBy string, memberIDs []string) (*database.Conversation, error) {
	c := &database.Conversation{
		ID:        fmt.Sprintf("conv-%d", time.Now().UnixNano()),
		Type:      convType,
		Title:     title,
		CreatedBy: createdBy,
		Members:   memberIDs,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if err := s.repo.CreateConversation(c); err != nil {
		return nil, err
	}
	return c, nil
}

// SendEncryptedEnvelope accepts an E2EE encrypted envelope, persists it, and dispatches sync events.
func (s *Service) SendEncryptedEnvelope(
	convID string,
	senderUserID string,
	senderDeviceID string,
	ciphertext string,
	idempotencyKey string,
	protocolVersion int,
) (*database.EncryptedMessageEnvelope, error) {
	if ciphertext == "" {
		return nil, ErrEmptyCiphertext
	}
	if protocolVersion <= 0 {
		protocolVersion = 1
	}

	msg := &database.EncryptedMessageEnvelope{
		ID:              fmt.Sprintf("msg-%d", time.Now().UnixNano()),
		ConversationID:  convID,
		SenderID:        senderUserID,
		SenderDeviceID:  senderDeviceID,
		ProtocolVersion: protocolVersion,
		Ciphertext:      ciphertext,
		IdempotencyKey:  idempotencyKey,
		CreatedAt:       time.Now(),
	}

	if err := s.repo.SaveEncryptedMessage(msg); err != nil {
		return nil, err
	}

	return msg, nil
}

// GetSyncEvents fetches ordered encrypted events for a user after a sequence cursor.
func (s *Service) GetSyncEvents(userID string, fromSeq int64) []*database.SyncEvent {
	return s.repo.GetSyncEvents(userID, fromSeq)
}
