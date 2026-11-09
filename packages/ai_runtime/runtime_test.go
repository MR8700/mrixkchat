package ai_runtime

import (
	"errors"
	"testing"
	"time"

	"mrixk.io/mrixk/packages/vector_memory"
)

func TestStrictCognitiveIsolation_UserA_CannotAccess_UserB(t *testing.T) {
	engine := NewLocalAIEngine()

	aliceID := "user-alice-001"
	bobID := "user-bob-002"

	aliceSpace := engine.GetOrCreateSpace(aliceID)
	bobSpace := engine.GetOrCreateSpace(bobID)

	// Alice records confidential memories and preferences
	aliceMemory := &vector_memory.MemoryEntry{
		ID:         "mem-alice-secret-01",
		OwnerID:    aliceID,
		Category:   "project",
		Content:    "Projet secret MRixk : lancement prévu fin 2026 avec clés Ed25519.",
		Confidence: 0.98,
		CreatedAt:  time.Now(),
		Embedding:  vector_memory.Embedding{0.8, 0.6, 0.1},
	}

	if err := aliceSpace.AddMemory(aliceMemory); err != nil {
		t.Fatalf("Failed to add Alice's memory: %v", err)
	}

	if err := aliceSpace.SetPreference(aliceID, "preferred_language", "fr"); err != nil {
		t.Fatalf("Failed to set Alice's preference: %v", err)
	}

	// 1. Verification: Bob attempts to directly query Alice's space -> MUST FAIL
	queryEmbedding := vector_memory.Embedding{0.8, 0.6, 0.1}
	_, err := aliceSpace.QueryMemories(bobID, "Projet secret", queryEmbedding)
	if !errors.Is(err, ErrAccessDenied) {
		t.Fatalf("Security vulnerability: Bob was able to query Alice's cognitive space! got error: %v", err)
	}

	// 2. Verification: Bob attempts to set preference in Alice's space -> MUST FAIL
	if err := aliceSpace.SetPreference(bobID, "malicious_key", "compromised"); !errors.Is(err, ErrAccessDenied) {
		t.Fatalf("Security vulnerability: Bob was able to write to Alice's preferences! got error: %v", err)
	}

	// 3. Verification: Bob queries his own space -> MUST BE EMPTY (0 results from Alice)
	bobResults, err := bobSpace.QueryMemories(bobID, "Projet secret", queryEmbedding)
	if err != nil {
		t.Fatalf("Bob failed to query his own space: %v", err)
	}
	if len(bobResults) != 0 {
		t.Fatalf("Cognitive leakage detected: Bob found %d memories in his space that belong to Alice!", len(bobResults))
	}

	// 4. Verification: Attempt to insert Alice's memory into Bob's space -> MUST FAIL
	maliciousAliceEntryInBob := &vector_memory.MemoryEntry{
		ID:         "mem-spoofed",
		OwnerID:    aliceID, // Sourced from Alice
		Content:    "Malicious injection",
		Confidence: 0.9,
	}
	if err := bobSpace.AddMemory(maliciousAliceEntryInBob); !errors.Is(err, ErrAccessDenied) {
		t.Fatalf("Security violation: Bob's space accepted a memory with owner Alice! error: %v", err)
	}

	// 5. Verification: Alice queries her own space -> SUCCEEDS
	aliceResults, err := aliceSpace.QueryMemories(aliceID, "Projet secret", queryEmbedding)
	if err != nil {
		t.Fatalf("Alice failed to query her own space: %v", err)
	}
	if len(aliceResults) != 1 || aliceResults[0].ID != "mem-alice-secret-01" {
		t.Fatalf("Alice should have retrieved her memory, got %d results", len(aliceResults))
	}
}

func TestKnowledgeGraph_Construction(t *testing.T) {
	aliceID := "user-alice-001"
	space := NewUserCognitiveSpace(aliceID)

	personNode := &KnowledgeNode{
		ID:        "node-person-1",
		OwnerID:   aliceID,
		Type:      "Person",
		Label:     "Richard Mare",
		CreatedAt: time.Now(),
	}

	projectNode := &KnowledgeNode{
		ID:        "node-project-1",
		OwnerID:   aliceID,
		Type:      "Project",
		Label:     "MRixk Security Core",
		CreatedAt: time.Now(),
	}

	edge := &KnowledgeEdge{
		ID:        "edge-1",
		OwnerID:   aliceID,
		FromNode:  personNode.ID,
		ToNode:    projectNode.ID,
		Relation:  "architects",
		Weight:    1.0,
		CreatedAt: time.Now(),
	}

	if err := space.AddKnowledgeNode(personNode); err != nil {
		t.Fatalf("Failed to add node: %v", err)
	}
	if err := space.AddKnowledgeNode(projectNode); err != nil {
		t.Fatalf("Failed to add node: %v", err)
	}
	if err := space.AddKnowledgeEdge(edge); err != nil {
		t.Fatalf("Failed to add edge: %v", err)
	}

	if len(space.GraphNodes) != 2 || len(space.GraphEdges) != 1 {
		t.Fatalf("Graph size mismatch: got %d nodes, %d edges", len(space.GraphNodes), len(space.GraphEdges))
	}
}
