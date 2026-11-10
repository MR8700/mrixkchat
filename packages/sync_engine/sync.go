package sync_engine

import (
	"errors"
	"fmt"
	"sync"
	"time"
)

var (
	ErrQueueFull        = errors.New("outbox queue limit reached")
	ErrMessageNotFound  = errors.New("outbox message not found")
	ErrDuplicateEvent   = errors.New("sync event already processed (replay ignored)")
)

type OutboxStatus string

const (
	StatusPending OutboxStatus = "PENDING"
	StatusSending OutboxStatus = "SENDING"
	StatusSent    OutboxStatus = "SENT"
	StatusFailed  OutboxStatus = "FAILED"
)

// OutboxItem represents a message prepared offline or awaiting transmission.
type OutboxItem struct {
	ID             string       `json:"id"`
	ConversationID string       `json:"conversation_id"`
	Ciphertext     string       `json:"ciphertext"` // E2EE payload
	IdempotencyKey string       `json:"idempotency_key"`
	Status         OutboxStatus `json:"status"`
	RetryCount     int          `json:"retry_count"`
	CreatedAt      time.Time    `json:"created_at"`
	LastAttemptAt  *time.Time   `json:"last_attempt_at,omitempty"`
}

// PersistentOutbox manages the local queue for offline-first message delivery.
type PersistentOutbox struct {
	items  map[string]*OutboxItem
	order  []string
	maxCap int
	mu     sync.RWMutex
}

// NewPersistentOutbox instantiates a local outbox.
func NewPersistentOutbox(capacity int) *PersistentOutbox {
	if capacity <= 0 {
		capacity = 1000
	}
	return &PersistentOutbox{
		items:  make(map[string]*OutboxItem),
		order:  make([]string, 0),
		maxCap: capacity,
	}
}

// Enqueue adds a message to the outbox queue.
func (o *PersistentOutbox) Enqueue(convID, ciphertext, idempotencyKey string) (*OutboxItem, error) {
	o.mu.Lock()
	defer o.mu.Unlock()

	if len(o.items) >= o.maxCap {
		return nil, ErrQueueFull
	}

	id := fmt.Sprintf("outbox-%d", time.Now().UnixNano())
	item := &OutboxItem{
		ID:             id,
		ConversationID: convID,
		Ciphertext:     ciphertext,
		IdempotencyKey: idempotencyKey,
		Status:         StatusPending,
		RetryCount:     0,
		CreatedAt:      time.Now(),
	}

	o.items[id] = item
	o.order = append(o.order, id)
	return item, nil
}

// GetPendingItems returns all messages ready to be dispatched upon reconnection.
func (o *PersistentOutbox) GetPendingItems() []*OutboxItem {
	o.mu.RLock()
	defer o.mu.RUnlock()

	var pending []*OutboxItem
	for _, id := range o.order {
		item := o.items[id]
		if item.Status == StatusPending || item.Status == StatusFailed {
			pending = append(pending, item)
		}
	}
	return pending
}

// MarkSending transitions message to sending state.
func (o *PersistentOutbox) MarkSending(id string) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	item, exists := o.items[id]
	if !exists {
		return ErrMessageNotFound
	}

	now := time.Now()
	item.Status = StatusSending
	item.LastAttemptAt = &now
	item.RetryCount++
	return nil
}

// MarkSent marks message as successfully delivered to server.
func (o *PersistentOutbox) MarkSent(id string) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	item, exists := o.items[id]
	if !exists {
		return ErrMessageNotFound
	}
	item.Status = StatusSent
	return nil
}

// MarkFailed increments retry count and marks as failed.
func (o *PersistentOutbox) MarkFailed(id string) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	item, exists := o.items[id]
	if !exists {
		return ErrMessageNotFound
	}
	item.Status = StatusFailed
	return nil
}

// DeviceSyncTracker tracks cursor and prevents replay attacks.
type DeviceSyncTracker struct {
	DeviceID      string
	LastSequence  int64
	seenSequences map[int64]bool
	mu            sync.RWMutex
}

// NewDeviceSyncTracker creates a sync cursor tracker for a device.
func NewDeviceSyncTracker(deviceID string, initialCursor int64) *DeviceSyncTracker {
	return &DeviceSyncTracker{
		DeviceID:      deviceID,
		LastSequence:  initialCursor,
		seenSequences: make(map[int64]bool),
	}
}

// ProcessSyncEvent verifies monotonic order and prevents duplicate event application.
func (t *DeviceSyncTracker) ProcessSyncEvent(sequence int64) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	if t.seenSequences[sequence] || sequence <= t.LastSequence {
		return ErrDuplicateEvent
	}

	t.seenSequences[sequence] = true
	t.LastSequence = sequence
	return nil
}
