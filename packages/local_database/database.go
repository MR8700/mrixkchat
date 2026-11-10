package local_database

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	ErrNotFound      = errors.New("record not found in local database")
	ErrAlreadyExists = errors.New("record already exists with this key")
	ErrClosed        = errors.New("database is closed")
)

// Document represents a generic JSON document.
type Document map[string]interface{}

// Database represents an embedded, thread-safe, disk-persistent local store.
type Database struct {
	path    string
	tables  map[string]map[string]Document
	mu      sync.RWMutex
	closed  bool
	autoSave bool
}

// Open opens or creates an embedded local database at the specified file path.
func Open(filePath string) (*Database, error) {
	db := &Database{
		path:     filePath,
		tables:   make(map[string]map[string]Document),
		autoSave: true,
	}

	if filePath != "" {
		if _, err := os.Stat(filePath); err == nil {
			if err := db.loadFromFile(filePath); err != nil {
				return nil, fmt.Errorf("failed to load local database: %w", err)
			}
		}
	}

	return db, nil
}

// SetAutoSave toggles whether mutations are automatically flushed to disk.
func (db *Database) SetAutoSave(enabled bool) {
	db.mu.Lock()
	defer db.mu.Unlock()
	db.autoSave = enabled
}

// Insert creates a new record in the specified table.
func (db *Database) Insert(table, key string, doc Document) error {
	db.mu.Lock()
	defer db.mu.Unlock()

	if db.closed {
		return ErrClosed
	}

	if _, exists := db.tables[table]; !exists {
		db.tables[table] = make(map[string]Document)
	}

	if _, exists := db.tables[table][key]; exists {
		return ErrAlreadyExists
	}

	// Clone document to protect internal state
	cloned := make(Document)
	for k, v := range doc {
		cloned[k] = v
	}
	cloned["_updated_at"] = time.Now().Format(time.RFC3339)

	db.tables[table][key] = cloned

	if db.autoSave && db.path != "" {
		_ = db.saveToFile(db.path)
	}

	return nil
}

// Get retrieves a record by table and key.
func (db *Database) Get(table, key string) (Document, error) {
	db.mu.RLock()
	defer db.mu.RUnlock()

	if db.closed {
		return nil, ErrClosed
	}

	t, exists := db.tables[table]
	if !exists {
		return nil, ErrNotFound
	}

	doc, exists := t[key]
	if !exists {
		return nil, ErrNotFound
	}

	cloned := make(Document)
	for k, v := range doc {
		cloned[k] = v
	}
	return cloned, nil
}

// Update updates an existing record in the specified table.
func (db *Database) Update(table, key string, doc Document) error {
	db.mu.Lock()
	defer db.mu.Unlock()

	if db.closed {
		return ErrClosed
	}

	t, exists := db.tables[table]
	if !exists {
		return ErrNotFound
	}

	if _, exists := t[key]; !exists {
		return ErrNotFound
	}

	cloned := make(Document)
	for k, v := range doc {
		cloned[k] = v
	}
	cloned["_updated_at"] = time.Now().Format(time.RFC3339)

	t[key] = cloned

	if db.autoSave && db.path != "" {
		_ = db.saveToFile(db.path)
	}

	return nil
}

// Delete removes a record from the specified table.
func (db *Database) Delete(table, key string) error {
	db.mu.Lock()
	defer db.mu.Unlock()

	if db.closed {
		return ErrClosed
	}

	t, exists := db.tables[table]
	if !exists {
		return ErrNotFound
	}

	if _, exists := t[key]; !exists {
		return ErrNotFound
	}

	delete(t, key)

	if db.autoSave && db.path != "" {
		_ = db.saveToFile(db.path)
	}

	return nil
}

// Query returns all documents in a table matching a predicate.
func (db *Database) Query(table string, predicate func(doc Document) bool) ([]Document, error) {
	db.mu.RLock()
	defer db.mu.RUnlock()

	if db.closed {
		return nil, ErrClosed
	}

	t, exists := db.tables[table]
	if !exists {
		return []Document{}, nil
	}

	var results []Document
	for _, doc := range t {
		if predicate == nil || predicate(doc) {
			cloned := make(Document)
			for k, v := range doc {
				cloned[k] = v
			}
			results = append(results, cloned)
		}
	}

	return results, nil
}

// Flush persists the entire database state to disk.
func (db *Database) Flush() error {
	db.mu.Lock()
	defer db.mu.Unlock()

	if db.closed {
		return ErrClosed
	}

	if db.path == "" {
		return nil
	}

	return db.saveToFile(db.path)
}

// Close flushes and closes the database.
func (db *Database) Close() error {
	db.mu.Lock()
	defer db.mu.Unlock()

	if db.closed {
		return nil
	}

	var err error
	if db.path != "" {
		err = db.saveToFile(db.path)
	}
	db.closed = true
	return err
}

func (db *Database) saveToFile(path string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	bytes, err := json.MarshalIndent(db.tables, "", "  ")
	if err != nil {
		return err
	}

	// Atomic write via temp file
	tmpPath := path + ".tmp"
	if err := os.WriteFile(tmpPath, bytes, 0644); err != nil {
		return err
	}

	return os.Rename(tmpPath, path)
}

func (db *Database) loadFromFile(path string) error {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	return json.Unmarshal(bytes, &db.tables)
}
