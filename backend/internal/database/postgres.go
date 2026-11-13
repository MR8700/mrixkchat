package database

import (
	"context"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

// PostgresPersister durably stores the full repository snapshot as JSONB in PostgreSQL.
type PostgresPersister struct {
	url  string
	mu   sync.Mutex
	conn *pgx.Conn
}

// NewPostgresPersister connects to PostgreSQL and ensures the state table exists.
func NewPostgresPersister(url string) (*PostgresPersister, error) {
	p := &PostgresPersister{url: url}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := p.ensureConn(ctx); err != nil {
		return nil, err
	}
	if _, err := p.conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS mrixk_state (
		id INT PRIMARY KEY,
		data JSONB NOT NULL,
		updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`); err != nil {
		return nil, err
	}
	return p, nil
}

func (p *PostgresPersister) ensureConn(ctx context.Context) error {
	if p.conn != nil && !p.conn.IsClosed() {
		if err := p.conn.Ping(ctx); err == nil {
			return nil
		}
		_ = p.conn.Close(ctx)
		p.conn = nil
	}
	c, err := pgx.Connect(ctx, p.url)
	if err != nil {
		return err
	}
	p.conn = c
	return nil
}

// Load returns the stored snapshot (nil if none yet).
func (p *PostgresPersister) Load() ([]byte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := p.ensureConn(ctx); err != nil {
		return nil, err
	}
	var data []byte
	err := p.conn.QueryRow(ctx, `SELECT data FROM mrixk_state WHERE id = 1`).Scan(&data)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return data, err
}

// Save upserts the snapshot.
func (p *PostgresPersister) Save(data []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := p.ensureConn(ctx); err != nil {
		return err
	}
	_, err := p.conn.Exec(ctx, `INSERT INTO mrixk_state (id, data, updated_at) VALUES (1, $1::jsonb, now())
		ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now()`, string(data))
	return err
}
