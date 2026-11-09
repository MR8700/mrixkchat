package vector_memory

import (
	"errors"
	"math"
	"strings"
	"time"
)

var (
	ErrDimensionMismatch = errors.New("vector dimensions do not match")
	ErrZeroVector        = errors.New("cannot compute similarity for zero vector")
)

// Embedding represents a dense numeric vector.
type Embedding []float64

// CosineSimilarity computes the cosine similarity between two vectors: (A . B) / (||A|| * ||B||).
func CosineSimilarity(a, b Embedding) (float64, error) {
	if len(a) != len(b) {
		return 0, ErrDimensionMismatch
	}
	if len(a) == 0 {
		return 0, ErrDimensionMismatch
	}

	var dot, normA, normB float64
	for i := range a {
		dot += a[i] * b[i]
		normA += a[i] * a[i]
		normB += b[i] * b[i]
	}

	if normA == 0 || normB == 0 {
		return 0, ErrZeroVector
	}

	return dot / (math.Sqrt(normA) * math.Sqrt(normB)), nil
}

// MemoryEntry represents a personal memory item stored in the local encrypted database.
type MemoryEntry struct {
	ID             string    `json:"memory_id"`
	OwnerID        string    `json:"owner_id"`
	Category       string    `json:"category"` // preference, project, fact, document, correction
	Content        string    `json:"content"`
	SourceType     string    `json:"source_type"` // conversation, document, manual
	SourceID       string    `json:"source_id"`
	Confidence     float64   `json:"confidence"` // 0.0 to 1.0
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
	UserValidated  bool      `json:"user_validated"`
	RetentionRule  string    `json:"retention_policy"` // persistent, ephemeral
	Embedding      Embedding `json:"-"`
}

// HybridWeights represents the parameters for the multi-factor retrieval score:
// Score = alpha*S_semantic + beta*S_lexical + gamma*S_recency + delta*S_confidence
type HybridWeights struct {
	Alpha float64 // Semantic weight (0.45)
	Beta  float64 // Lexical weight (0.25)
	Gamma float64 // Recency weight (0.15)
	Delta float64 // Confidence weight (0.15)
}

// DefaultWeights returns the standardized weights calibrated for MRixk local retrieval.
func DefaultWeights() HybridWeights {
	return HybridWeights{
		Alpha: 0.45,
		Beta:  0.25,
		Gamma: 0.15,
		Delta: 0.15,
	}
}

// ComputeLexicalScore computes a token overlap (Jaccard/TF) score between query and document.
func ComputeLexicalScore(query, content string) float64 {
	queryTokens := tokenize(query)
	contentTokens := tokenize(content)
	if len(queryTokens) == 0 || len(contentTokens) == 0 {
		return 0.0
	}

	contentMap := make(map[string]int)
	for _, t := range contentTokens {
		contentMap[t]++
	}

	matches := 0
	for _, qt := range queryTokens {
		if contentMap[qt] > 0 {
			matches++
		}
	}
	return float64(matches) / float64(len(queryTokens))
}

// ComputeRecencyScore applies exponential time-decay over days.
// Half-life is 30 days.
func ComputeRecencyScore(createdAt time.Time, now time.Time) float64 {
	diffHours := now.Sub(createdAt).Hours()
	if diffHours < 0 {
		diffHours = 0
	}
	diffDays := diffHours / 24.0
	// Half-life decay: 2^(-days / 30)
	decay := math.Pow(2.0, -diffDays/30.0)
	return decay
}

// ComputeHybridScore computes the overall relevance score according to MRixk specifications.
func ComputeHybridScore(
	semanticScore float64,
	query string,
	entry *MemoryEntry,
	weights HybridWeights,
	now time.Time,
) float64 {
	lexicalScore := ComputeLexicalScore(query, entry.Content)
	recencyScore := ComputeRecencyScore(entry.CreatedAt, now)
	confidenceScore := entry.Confidence
	if confidenceScore < 0 {
		confidenceScore = 0
	} else if confidenceScore > 1.0 {
		confidenceScore = 1.0
	}

	score := (weights.Alpha * semanticScore) +
		(weights.Beta * lexicalScore) +
		(weights.Gamma * recencyScore) +
		(weights.Delta * confidenceScore)

	return score
}

func tokenize(s string) []string {
	fields := strings.Fields(strings.ToLower(s))
	var tokens []string
	for _, f := range fields {
		clean := strings.Trim(f, ".,!?:;\"'()[]{}")
		if len(clean) > 1 {
			tokens = append(tokens, clean)
		}
	}
	return tokens
}
