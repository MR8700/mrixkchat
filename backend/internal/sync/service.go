package sync

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"mrixk.io/mrixk/packages/sync_engine"
)

var (
	ErrSyncInvalidCursor = errors.New("invalid sync cursor")
)

type EventEnvelope struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"` // MESSAGE, TOMBSTONE, REACTION, DEVICE_REVOKED
	Payload   string    `json:"payload"`
	Sequence  int64     `json:"sequence"`
	CreatedAt time.Time `json:"created_at"`
}

type Service struct {
	userEvents map[string][]*EventEnvelope // UserID -> list of chronological events
	outbox     *sync_engine.PersistentOutbox
	seqCounter int64
	mu         sync.RWMutex
}

func NewService() *Service {
	return &Service{
		userEvents: make(map[string][]*EventEnvelope),
		outbox:     sync_engine.NewPersistentOutbox(5000),
		seqCounter: 0,
	}
}

func (s *Service) PublishEvent(userID, eventType, encryptedPayload string) *EventEnvelope {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.seqCounter++
	env := &EventEnvelope{
		ID:        fmt.Sprintf("ev-%d-%d", s.seqCounter, time.Now().UnixNano()),
		Type:      eventType,
		Payload:   encryptedPayload,
		Sequence:  s.seqCounter,
		CreatedAt: time.Now(),
	}

	s.userEvents[userID] = append(s.userEvents[userID], env)
	return env
}

func (s *Service) GetDeltaEvents(userID string, sinceCursor int64) []*EventEnvelope {
	s.mu.RLock()
	defer s.mu.RUnlock()

	events := s.userEvents[userID]
	var delta []*EventEnvelope
	for _, e := range events {
		if e.Sequence > sinceCursor {
			delta = append(delta, e)
		}
	}
	return delta
}
