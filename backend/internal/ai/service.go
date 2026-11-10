package ai

import (
	"errors"
	"sync"

	"mrixk.io/mrixk/packages/ai_runtime"
)

var (
	ErrContextTooShort = errors.New("prompt context is empty")
)

type AIQueryRequest struct {
	UserID string `json:"user_id"`
	Prompt string `json:"prompt"`
}

type AIQueryResponse struct {
	Answer     string   `json:"answer"`
	Confidence float64  `json:"confidence"`
	Sources    []string `json:"sources"`
}

type Service struct {
	spaces map[string]*ai_runtime.UserCognitiveSpace
	mu     sync.RWMutex
}

func NewService() *Service {
	return &Service{
		spaces: make(map[string]*ai_runtime.UserCognitiveSpace),
	}
}

func (s *Service) GetOrCreateSpace(userID string) *ai_runtime.UserCognitiveSpace {
	s.mu.Lock()
	defer s.mu.Unlock()

	if space, exists := s.spaces[userID]; exists {
		return space
	}
	space := ai_runtime.NewUserCognitiveSpace(userID)
	s.spaces[userID] = space
	return space
}

func (s *Service) ProcessQuery(req AIQueryRequest) (*AIQueryResponse, error) {
	if req.Prompt == "" {
		return nil, ErrContextTooShort
	}

	space := s.GetOrCreateSpace(req.UserID)

	// Search relevant semantic memories
	memories, _ := space.QueryMemories(req.UserID, req.Prompt, nil)

	var sources []string
	for _, m := range memories {
		sources = append(sources, m.Content)
	}

	answer := "Je traite votre requête en toute confidentialité selon votre mémoire locale."
	if len(sources) > 0 {
		answer = "D'après vos notes et préférences protégées : " + sources[0]
	}

	return &AIQueryResponse{
		Answer:     answer,
		Confidence: 0.95,
		Sources:    sources,
	}, nil
}
