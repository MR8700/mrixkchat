package sync_engine

import (
	"errors"
	"testing"
)

func TestPersistentOutbox_OfflineQueueAndStateTransitions(t *testing.T) {
	outbox := NewPersistentOutbox(5)

	// 1. Enqueue 2 messages while offline
	item1, err := outbox.Enqueue("conv-1", "ENCRYPTED_PAYLOAD_1", "idem-001")
	if err != nil {
		t.Fatalf("Failed to enqueue item 1: %v", err)
	}

	item2, err := outbox.Enqueue("conv-1", "ENCRYPTED_PAYLOAD_2", "idem-002")
	if err != nil {
		t.Fatalf("Failed to enqueue item 2: %v", err)
	}

	pending := outbox.GetPendingItems()
	if len(pending) != 2 {
		t.Fatalf("Expected 2 pending items, got %d", len(pending))
	}
	if pending[0].ID != item1.ID || pending[1].ID != item2.ID {
		t.Fatalf("FIFO order violated in outbox queue")
	}

	// 2. Mark item 1 sending -> sent
	if err := outbox.MarkSending(item1.ID); err != nil {
		t.Fatalf("Failed to mark sending: %v", err)
	}
	if err := outbox.MarkSent(item1.ID); err != nil {
		t.Fatalf("Failed to mark sent: %v", err)
	}

	// 3. Mark item 2 sending -> failed (e.g. timeout)
	if err := outbox.MarkSending(item2.ID); err != nil {
		t.Fatalf("Failed to mark sending: %v", err)
	}
	if err := outbox.MarkFailed(item2.ID); err != nil {
		t.Fatalf("Failed to mark failed: %v", err)
	}

	// Pending items should now contain only item 2 for retry
	pendingAfter := outbox.GetPendingItems()
	if len(pendingAfter) != 1 || pendingAfter[0].ID != item2.ID {
		t.Fatalf("Failed item should be present in pending retry queue")
	}
	if pendingAfter[0].RetryCount != 1 {
		t.Fatalf("Retry count should be 1, got %d", pendingAfter[0].RetryCount)
	}
}

func TestDeviceSyncTracker_MonotonicOrderAndAntiReplay(t *testing.T) {
	tracker := NewDeviceSyncTracker("dev-001", 0)

	// Accept seq 1
	if err := tracker.ProcessSyncEvent(1); err != nil {
		t.Fatalf("Failed to process event 1: %v", err)
	}

	// Accept seq 2
	if err := tracker.ProcessSyncEvent(2); err != nil {
		t.Fatalf("Failed to process event 2: %v", err)
	}

	if tracker.LastSequence != 2 {
		t.Fatalf("Expected last sequence 2, got %d", tracker.LastSequence)
	}

	// REPLAY ATTACK: Re-sending sequence 1 or 2 must fail!
	if err := tracker.ProcessSyncEvent(1); !errors.Is(err, ErrDuplicateEvent) {
		t.Fatalf("Expected ErrDuplicateEvent on replayed sequence 1, got: %v", err)
	}
	if err := tracker.ProcessSyncEvent(2); !errors.Is(err, ErrDuplicateEvent) {
		t.Fatalf("Expected ErrDuplicateEvent on duplicate sequence 2, got: %v", err)
	}

	// Older sequence 0 must also fail
	if err := tracker.ProcessSyncEvent(0); !errors.Is(err, ErrDuplicateEvent) {
		t.Fatalf("Expected ErrDuplicateEvent on older sequence 0, got: %v", err)
	}
}
