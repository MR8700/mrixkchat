package vector_memory

import (
	"math"
	"testing"
	"time"
)

func TestCosineSimilarity(t *testing.T) {
	// Identical vectors -> 1.0
	v1 := Embedding{1.0, 2.0, 3.0}
	v2 := Embedding{1.0, 2.0, 3.0}
	sim, err := CosineSimilarity(v1, v2)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}
	if math.Abs(sim-1.0) > 1e-6 {
		t.Fatalf("Expected similarity 1.0, got %f", sim)
	}

	// Orthogonal vectors -> 0.0
	vOrth1 := Embedding{1.0, 0.0}
	vOrth2 := Embedding{0.0, 1.0}
	simOrth, err := CosineSimilarity(vOrth1, vOrth2)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}
	if math.Abs(simOrth) > 1e-6 {
		t.Fatalf("Expected orthogonal similarity 0.0, got %f", simOrth)
	}

	// Dimension mismatch error
	v3 := Embedding{1.0, 2.0}
	if _, err := CosineSimilarity(v1, v3); err != ErrDimensionMismatch {
		t.Fatalf("Expected ErrDimensionMismatch, got %v", err)
	}
}

func TestLexicalScore(t *testing.T) {
	query := "projet chiffrement mobile"
	content := "Le projet MRixk met en place un chiffrement de bout en bout sur mobile."
	score := ComputeLexicalScore(query, content)
	if score != 1.0 {
		t.Fatalf("Expected perfect lexical match 1.0 (all 3 words present), got %f", score)
	}

	noMatchContent := "Recette de cuisine pour tarte aux pommes."
	scoreNoMatch := ComputeLexicalScore(query, noMatchContent)
	if scoreNoMatch != 0.0 {
		t.Fatalf("Expected 0.0 lexical match, got %f", scoreNoMatch)
	}
}

func TestRecencyScore(t *testing.T) {
	now := time.Now()
	// Created right now -> 1.0
	scoreNow := ComputeRecencyScore(now, now)
	if math.Abs(scoreNow-1.0) > 1e-4 {
		t.Fatalf("Expected recency 1.0 for today, got %f", scoreNow)
	}

	// Created 30 days ago -> 0.5 (half-life)
	thirtyDaysAgo := now.Add(-30 * 24 * time.Hour)
	score30 := ComputeRecencyScore(thirtyDaysAgo, now)
	if math.Abs(score30-0.5) > 0.01 {
		t.Fatalf("Expected recency ~0.5 for 30 days ago, got %f", score30)
	}
}

func TestComputeHybridScore(t *testing.T) {
	now := time.Now()
	entry := &MemoryEntry{
		ID:         "mem-1",
		OwnerID:    "user-1",
		Content:    "Serveur Go modulaire et cryptographie robuste",
		Confidence: 0.9,
		CreatedAt:  now,
	}

	weights := DefaultWeights() // 0.45, 0.25, 0.15, 0.15
	semanticScore := 0.8
	query := "Serveur cryptographie"

	// Lexical: both "serveur" and "cryptographie" match query -> 1.0
	// Recency: now -> 1.0
	// Confidence: 0.9
	// Score = 0.45*0.8 + 0.25*1.0 + 0.15*1.0 + 0.15*0.9
	//       = 0.36 + 0.25 + 0.15 + 0.135 = 0.895
	score := ComputeHybridScore(semanticScore, query, entry, weights, now)
	expected := 0.895
	if math.Abs(score-expected) > 1e-4 {
		t.Fatalf("Expected hybrid score %f, got %f", expected, score)
	}
}
