package database

import (
	"errors"
	"testing"
	"time"
)

type memPersister struct{ data []byte }

func (m *memPersister) Save(d []byte) error   { m.data = append([]byte(nil), d...); return nil }
func (m *memPersister) Load() ([]byte, error) { return m.data, nil }

type failingPersister struct {
	data []byte
	err  error
}

func (p *failingPersister) Save(data []byte) error {
	if p.err != nil {
		return p.err
	}
	p.data = append([]byte(nil), data...)
	return nil
}
func (p *failingPersister) Load() ([]byte, error) { return p.data, nil }

func TestDeleteUserCascadeAndReservation(t *testing.T) {
	repo := NewMemoryRepository(3)
	p := &memPersister{}
	if err := repo.SetPersister(p); err != nil {
		t.Fatal(err)
	}
	a := &User{ID: "u1", Handle: "@alice", DisplayName: "Alice", RecoveryCode: "MRX-A"}
	b := &User{ID: "u2", Handle: "@bob", DisplayName: "Bob", RecoveryCode: "MRX-B"}
	c := &User{ID: "u3", Handle: "@carl", DisplayName: "Carl", RecoveryCode: "MRX-C"}
	for _, u := range []*User{a, b, c} {
		if err := repo.CreateUser(u); err != nil {
			t.Fatal(err)
		}
	}
	_ = repo.CreateConversation(&Conversation{ID: "g1", Type: "GROUP", CreatedBy: "u1", Members: []string{"u1", "u2", "u3"}})
	_ = repo.CreateConversation(&Conversation{ID: "d1", Type: "DIRECT", CreatedBy: "u1", Members: []string{"u1", "u2"}})

	if err := repo.DeleteUser("u1"); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.GetUserByID("u1"); err == nil {
		t.Fatal("user should be gone")
	}
	if len(repo.SearchUsers("")) != 2 {
		t.Fatal("deleted user must not be discoverable")
	}
	g, _ := repo.GetConversation("g1")
	if len(g.Members) != 2 || g.CreatedBy == "u1" {
		t.Fatalf("group not updated: %+v", g)
	}
	d, err := repo.GetConversation("d1")
	if err != nil || len(d.Members) != 1 || d.Members[0] != "u2" {
		t.Fatal("direct conversation should remain for the surviving user")
	}
	events := repo.GetSyncEvents("u2", 0)
	found := false
	for _, ev := range events {
		if ev.EventType == "USER_DELETED" {
			found = true
		}
	}
	if !found {
		t.Fatal("affected user should receive a durable deletion event")
	}
	// handle reserved for 24h
	if err := repo.CreateUser(&User{ID: "u9", Handle: "@alice"}); err != ErrHandleAlreadyTaken {
		t.Fatalf("handle must be reserved, got %v", err)
	}
	active, deleted := repo.UserStatuses([]string{"u1", "u2", "zzz"})
	if len(active) != 1 || len(deleted) != 1 || deleted[0].UserID != "u1" {
		t.Fatal("status reconciliation wrong")
	}
	// reservation expiry
	repo.tombstones["u1"].ReservedUntil = time.Now().Add(-time.Minute)
	if err := repo.CreateUser(&User{ID: "u9", Handle: "@alice"}); err != nil {
		t.Fatalf("handle should be free after 24h: %v", err)
	}

	// durable round-trip (tombstones included)
	repo2 := NewMemoryRepository(3)
	if err := repo2.SetPersister(p); err != nil {
		t.Fatal(err)
	}
	if _, ok := repo2.GetTombstone("u1"); !ok {
		t.Fatal("tombstone must survive restart")
	}
	if _, err := repo2.GetUserByHandle("@bob"); err != nil {
		t.Fatal("users must survive restart")
	}
}

func TestDeleteUserRollsBackWhenDurableSaveFails(t *testing.T) {
	repo := NewMemoryRepository(3)
	if err := repo.CreateUser(&User{ID: "u1", Handle: "@alice", RecoveryCode: "MRX-A"}); err != nil {
		t.Fatal(err)
	}
	persister := &failingPersister{}
	if err := repo.SetPersister(persister); err != nil {
		t.Fatal(err)
	}
	persister.err = errors.New("database unavailable")
	if err := repo.DeleteUser("u1"); err == nil {
		t.Fatal("delete must fail when durable persistence fails")
	}
	if _, err := repo.GetUserByID("u1"); err != nil {
		t.Fatal("failed delete must preserve the in-memory account")
	}
	if _, ok := repo.GetTombstone("u1"); ok {
		t.Fatal("failed delete must not leave a tombstone")
	}
}

func TestCreateUserRollsBackWhenDurableSaveFails(t *testing.T) {
	repo := NewMemoryRepository(3)
	persister := &failingPersister{err: errors.New("database unavailable")}
	if err := repo.SetPersister(persister); err != nil {
		t.Fatal(err)
	}
	if err := repo.CreateUser(&User{ID: "u1", Handle: "@alice", RecoveryCode: "MRX-A"}); err == nil {
		t.Fatal("registration must fail when durable persistence fails")
	}
	if _, err := repo.GetUserByID("u1"); err == nil {
		t.Fatal("failed registration must not leave an in-memory user")
	}
}
