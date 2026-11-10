package social

import (
	"errors"
	"sync"
	"time"
)

var (
	ErrMomentNotFound = errors.New("moment not found")
	ErrMomentExpired  = errors.New("moment has expired")
)

type Moment struct {
	ID           string            `json:"id"`
	AuthorID     string            `json:"author_id"`
	AuthorName   string            `json:"author_name"`
	AuthorHandle string            `json:"author_handle"`
	Type         string            `json:"type"` // image, voice, quote
	MediaURL     string            `json:"media_url,omitempty"`
	TextContent  string            `json:"text_content,omitempty"`
	Duration     string            `json:"duration,omitempty"`
	Reactions    map[string]int    `json:"reactions"`
	CreatedAt    time.Time         `json:"created_at"`
	ExpiresAt    time.Time         `json:"expires_at"`
}

type Service struct {
	moments map[string]*Moment
	mu      sync.RWMutex
}

func NewService() *Service {
	return &Service{
		moments: make(map[string]*Moment),
	}
}

func (s *Service) CreateMoment(id, authorID, authorName, authorHandle, mType, mediaURL, text, duration string, ttl time.Duration) *Moment {
	if ttl <= 0 {
		ttl = 24 * time.Hour // Default 24h ephemeral story
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	m := &Moment{
		ID:           id,
		AuthorID:     authorID,
		AuthorName:   authorName,
		AuthorHandle: authorHandle,
		Type:         mType,
		MediaURL:     mediaURL,
		TextContent:  text,
		Duration:     duration,
		Reactions:    make(map[string]int),
		CreatedAt:    now,
		ExpiresAt:    now.Add(ttl),
	}
	s.moments[id] = m
	return m
}

func (s *Service) GetActiveMoments() []*Moment {
	s.mu.RLock()
	defer s.mu.RUnlock()

	now := time.Now()
	var active []*Moment
	for _, m := range s.moments {
		if now.Before(m.ExpiresAt) {
			active = append(active, m)
		}
	}
	return active
}

func (s *Service) ToggleReaction(momentID, emoji string) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	m, exists := s.moments[momentID]
	if !exists {
		return 0, ErrMomentNotFound
	}
	if time.Now().After(m.ExpiresAt) {
		return 0, ErrMomentExpired
	}

	m.Reactions[emoji]++
	return m.Reactions[emoji], nil
}
