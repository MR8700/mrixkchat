package ai_runtime

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"mrixk.io/mrixk/packages/vector_memory"
)

var (
	ErrAccessDenied       = errors.New("security violation: cross-user cognitive access forbidden")
	ErrMemoryNotFound     = errors.New("memory entry not found")
	ErrInvalidConfidence = errors.New("confidence must be between 0.0 and 1.0")
)

// InformationNature classifies the origin and certainty of an AI memory.
type InformationNature string

const (
	NatureDeclared   InformationNature = "declared"   // Explicitly stated by the user
	NatureDocument   InformationNature = "document"   // Extracted from an authorized file
	NatureDeduction  InformationNature = "deduction"  // Logically deduced with confidence
	NatureHypothesis InformationNature = "hypothesis" // Working hypothesis pending validation
	NatureUnknown    InformationNature = "unknown"    // Explicitly unverified / unknown
)

// KnowledgeNode represents a node in the user's personal knowledge graph.
type KnowledgeNode struct {
	ID        string            `json:"id"`
	OwnerID   string            `json:"owner_id"`
	Type      string            `json:"type"` // Person, Project, Concept, Preference
	Label     string            `json:"label"`
	Metadata  map[string]string `json:"metadata"`
	CreatedAt time.Time         `json:"created_at"`
}

// KnowledgeEdge represents a directed relationship in the user's personal knowledge graph.
type KnowledgeEdge struct {
	ID        string    `json:"id"`
	OwnerID   string    `json:"owner_id"`
	FromNode  string    `json:"from_node"`
	ToNode    string    `json:"to_node"`
	Relation  string    `json:"relation"` // "works_on", "prefers", "knows"
	Weight    float64   `json:"weight"`
	CreatedAt time.Time `json:"created_at"`
}

// UserCognitiveSpace encapsulates M(u) = {D_u, V_u, G_u, P_u, H_u}.
// Stored strictly locally on the user's authorized device.
type UserCognitiveSpace struct {
	OwnerID     string                                  `json:"owner_id"`
	Documents   map[string]string                       `json:"documents"` // D(u)
	Memories    map[string]*vector_memory.MemoryEntry   `json:"memories"`  // V(u)
	GraphNodes  map[string]*KnowledgeNode               `json:"nodes"`     // G(u) nodes
	GraphEdges  map[string]*KnowledgeEdge               `json:"edges"`     // G(u) edges
	Preferences map[string]string                       `json:"preferences"` // P(u)
	History     []string                                `json:"history"`     // H(u)
	mu          sync.RWMutex
}

// NewUserCognitiveSpace instantiates an isolated cognitive container for an authorized user.
func NewUserCognitiveSpace(ownerID string) *UserCognitiveSpace {
	return &UserCognitiveSpace{
		OwnerID:     ownerID,
		Documents:   make(map[string]string),
		Memories:    make(map[string]*vector_memory.MemoryEntry),
		GraphNodes:  make(map[string]*KnowledgeNode),
		GraphEdges:  make(map[string]*KnowledgeEdge),
		Preferences: make(map[string]string),
		History:     make([]string, 0),
	}
}

// LocalAIEngine orchestrates cognitive operations across isolated spaces.
type LocalAIEngine struct {
	spaces map[string]*UserCognitiveSpace
	mu     sync.RWMutex
}

// NewLocalAIEngine initializes the local AI engine.
func NewLocalAIEngine() *LocalAIEngine {
	return &LocalAIEngine{
		spaces: make(map[string]*UserCognitiveSpace),
	}
}

// GetOrCreateSpace returns the cognitive space for the requesting user.
func (e *LocalAIEngine) GetOrCreateSpace(userID string) *UserCognitiveSpace {
	e.mu.Lock()
	defer e.mu.Unlock()
	space, exists := e.spaces[userID]
	if !exists {
		space = NewUserCognitiveSpace(userID)
		e.spaces[userID] = space
	}
	return space
}

// AddMemory records a new memory item ensuring strict owner association.
func (space *UserCognitiveSpace) AddMemory(entry *vector_memory.MemoryEntry) error {
	space.mu.Lock()
	defer space.mu.Unlock()

	if entry.OwnerID != space.OwnerID {
		return fmt.Errorf("%w: cannot store memory belonging to user %s in space of user %s",
			ErrAccessDenied, entry.OwnerID, space.OwnerID)
	}
	if entry.Confidence < 0.0 || entry.Confidence > 1.0 {
		return ErrInvalidConfidence
	}
	space.Memories[entry.ID] = entry
	space.History = append(space.History, fmt.Sprintf("Added memory %s (%s)", entry.ID, entry.Category))
	return nil
}

// QueryMemories retrieves memories using hybrid search, strictly restricted to the caller's space.
func (space *UserCognitiveSpace) QueryMemories(requestingUserID string, query string, queryEmbedding vector_memory.Embedding) ([]*vector_memory.MemoryEntry, error) {
	space.mu.RLock()
	defer space.mu.RUnlock()

	// Strict tenancy enforcement
	if requestingUserID != space.OwnerID {
		return nil, fmt.Errorf("%w: requesting user %s cannot access cognitive memory of %s",
			ErrAccessDenied, requestingUserID, space.OwnerID)
	}

	weights := vector_memory.DefaultWeights()
	now := time.Now()

	type scoredItem struct {
		entry *vector_memory.MemoryEntry
		score float64
	}

	var scored []scoredItem
	for _, entry := range space.Memories {
		semanticScore := 0.0
		if len(queryEmbedding) > 0 && len(entry.Embedding) > 0 {
			if sim, err := vector_memory.CosineSimilarity(queryEmbedding, entry.Embedding); err == nil {
				// Normalize cosine similarity from [-1, 1] to [0, 1]
				semanticScore = (sim + 1.0) / 2.0
			}
		}
		totalScore := vector_memory.ComputeHybridScore(semanticScore, query, entry, weights, now)
		if totalScore > 0.2 { // Minimum relevance threshold
			scored = append(scored, scoredItem{entry: entry, score: totalScore})
		}
	}

	// Simple bubble/sort top results
	results := make([]*vector_memory.MemoryEntry, len(scored))
	for i, s := range scored {
		results[i] = s.entry
	}
	return results, nil
}

// SetPreference saves a validated personal preference.
func (space *UserCognitiveSpace) SetPreference(requestingUserID, key, value string) error {
	space.mu.Lock()
	defer space.mu.Unlock()

	if requestingUserID != space.OwnerID {
		return ErrAccessDenied
	}
	space.Preferences[key] = value
	return nil
}

// AddKnowledgeNode inserts an entity into the personal knowledge graph.
func (space *UserCognitiveSpace) AddKnowledgeNode(node *KnowledgeNode) error {
	space.mu.Lock()
	defer space.mu.Unlock()

	if node.OwnerID != space.OwnerID {
		return ErrAccessDenied
	}
	space.GraphNodes[node.ID] = node
	return nil
}

// AddKnowledgeEdge inserts a relationship into the personal knowledge graph.
func (space *UserCognitiveSpace) AddKnowledgeEdge(edge *KnowledgeEdge) error {
	space.mu.Lock()
	defer space.mu.Unlock()

	if edge.OwnerID != space.OwnerID {
		return ErrAccessDenied
	}
	space.GraphEdges[edge.ID] = edge
	return nil
}
