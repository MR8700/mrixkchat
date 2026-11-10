package local_database

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLocalDatabaseCRUDAndPersistence(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "mrixk_db_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	dbPath := filepath.Join(tempDir, "test_local.json")

	// 1. Open new database
	db, err := Open(dbPath)
	if err != nil {
		t.Fatalf("failed to open database: %v", err)
	}

	// 2. Insert records
	doc1 := Document{
		"title":     "Document Confidentiel",
		"encrypted": true,
		"author":    "Richard",
	}
	if err := db.Insert("documents", "doc_1", doc1); err != nil {
		t.Fatalf("insert failed: %v", err)
	}

	// 3. Read record
	got, err := db.Get("documents", "doc_1")
	if err != nil {
		t.Fatalf("get failed: %v", err)
	}
	if got["author"] != "Richard" {
		t.Errorf("author mismatch: got %v, want Richard", got["author"])
	}

	// 4. Update record
	doc1["author"] = "Richard MARE"
	if err := db.Update("documents", "doc_1", doc1); err != nil {
		t.Fatalf("update failed: %v", err)
	}

	// 5. Close database
	if err := db.Close(); err != nil {
		t.Fatalf("close failed: %v", err)
	}

	// 6. Reopen from disk and verify persistence
	db2, err := Open(dbPath)
	if err != nil {
		t.Fatalf("reopen failed: %v", err)
	}
	defer db2.Close()

	got2, err := db2.Get("documents", "doc_1")
	if err != nil {
		t.Fatalf("get after reopen failed: %v", err)
	}
	if got2["author"] != "Richard MARE" {
		t.Errorf("author mismatch after reopen: got %v, want Richard MARE", got2["author"])
	}

	// 7. Query with predicate
	results, err := db2.Query("documents", func(d Document) bool {
		return d["encrypted"] == true
	})
	if err != nil {
		t.Fatalf("query failed: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("query results count mismatch: got %d, want 1", len(results))
	}

	// 8. Delete record
	if err := db2.Delete("documents", "doc_1"); err != nil {
		t.Fatalf("delete failed: %v", err)
	}

	_, err = db2.Get("documents", "doc_1")
	if err != ErrNotFound {
		t.Errorf("expected ErrNotFound after delete, got %v", err)
	}
}
