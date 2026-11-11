package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/documents"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/messaging"
)

type testClient struct {
	server       *Server
	userID       string
	sessionToken string
}

func registerAndAuthDevice(t *testing.T, s *Server, handle, password, deviceName string) *testClient {
	t.Helper()
	regPayload := fmt.Sprintf(`{"handle":"%s","password":"%s","display_name":"Test User"}`, handle, password)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewBufferString(regPayload))
	s.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Register %s failed: %d, body: %s", handle, rec.Code, rec.Body.String())
	}

	var regResp struct {
		User database.User `json:"user"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &regResp)

	authPayload := fmt.Sprintf(`{"user_id":"%s","password":"%s","device_name":"%s","platform":"Linux","identity_public_key":"pub-%s","diffie_hellman_public_key":"dh-%s"}`,
		regResp.User.ID, password, deviceName, handle, handle)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(authPayload))
	s.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Auth device for %s failed: %d, body: %s", handle, rec.Code, rec.Body.String())
	}

	var authResp struct {
		SessionToken string `json:"session_token"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &authResp)

	return &testClient{
		server:       s,
		userID:       regResp.User.ID,
		sessionToken: authResp.SessionToken,
	}
}

func (c *testClient) doRequest(t *testing.T, method, path string, body interface{}) *httptest.ResponseRecorder {
	t.Helper()
	var bodyBuf *bytes.Buffer
	if body != nil {
		switch v := body.(type) {
		case string:
			bodyBuf = bytes.NewBufferString(v)
		default:
			data, err := json.Marshal(v)
			if err != nil {
				t.Fatalf("JSON marshal error: %v", err)
			}
			bodyBuf = bytes.NewBuffer(data)
		}
	} else {
		bodyBuf = bytes.NewBuffer(nil)
	}

	req := httptest.NewRequest(method, path, bodyBuf)
	req.Header.Set("Authorization", "Bearer "+c.sessionToken)
	req.Header.Set("Content-Type", "application/json")

	rec := httptest.NewRecorder()
	c.server.ServeHTTP(rec, req)
	return rec
}

func TestGroupDocuments_EndToEnd_SecurityAndWorkflow(t *testing.T) {
	repo := database.NewMemoryRepository(5)
	idService := identity.NewService(repo)
	deviceService := devices.NewService(repo)
	msgService := messaging.NewService(repo)
	server := NewServer(idService, deviceService, msgService, repo)

	// Setup 3 users: Alice (Owner), Bob (Member/Mod), Mallory (Attacker / Non-member)
	alice := registerAndAuthDevice(t, server, "@alice", "PasswordAlice123!", "Alice-Laptop")
	bob := registerAndAuthDevice(t, server, "@bob", "PasswordBob123!", "Bob-Phone")
	mallory := registerAndAuthDevice(t, server, "@mallory", "PasswordMallory123!", "Mallory-Hacker")

	// Alice creates a group conversation with Alice and Bob
	createGroupPayload := map[string]interface{}{
		"type":    "GROUP",
		"title":   "MRixk Security Core Team",
		"members": []string{bob.userID},
	}
	rec := alice.doRequest(t, http.MethodPost, "/api/v1/conversations", createGroupPayload)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Alice failed to create group: %d, %s", rec.Code, rec.Body.String())
	}
	var groupResp struct {
		Conversation database.Conversation `json:"conversation"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &groupResp)
	groupID := groupResp.Conversation.ID

	// 1. IDOR Prevention: Mallory (non-member) tries to get document before it's even created -> 403 Forbidden
	rec = mallory.doRequest(t, http.MethodGet, fmt.Sprintf("/api/v1/groups/%s/documents", groupID), nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("Security failure: Non-member Mallory should receive 403, got %d", rec.Code)
	}

	// 2. Alice creates primary group document with components and custom spacing
	createDocReq := map[string]interface{}{
		"title":             "Architecture & Sécurité MRixk",
		"encrypted_content": "Introduction au système {{tableau1}}\n\nFormule d'entropie:\n{{formule1}}\nFin du rapport.",
		"components": map[string]string{
			"tableau1": "<table class='mrixk-table'><tr><th>Module</th><th>Chiffrement</th></tr><tr><td>Documents</td><td>AES-256-GCM</td></tr></table>",
			"formule1": "<math><mrow><mi>H</mi><mo>(</mo><mi>X</mi><mo>)</mo></mrow></math>",
		},
		"line_spacing":      1.8,
		"paragraph_spacing": 22.0,
	}
	rec = alice.doRequest(t, http.MethodPost, fmt.Sprintf("/api/v1/groups/%s/documents", groupID), createDocReq)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Alice failed to create document: %d, body: %s", rec.Code, rec.Body.String())
	}
	var docResp struct {
		Document documents.GroupDocument `json:"document"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &docResp)
	docID := docResp.Document.ID

	if docResp.Document.CurrentVersion != 1 {
		t.Fatalf("Expected version 1, got %d", docResp.Document.CurrentVersion)
	}
	if docResp.Document.LineSpacing != 1.8 || docResp.Document.ParagraphSpacing != 22.0 {
		t.Fatalf("Spacing settings not preserved: line=%f, para=%f", docResp.Document.LineSpacing, docResp.Document.ParagraphSpacing)
	}

	// 3. Bob (Group Member) reads the document -> 200 OK
	rec = bob.doRequest(t, http.MethodGet, fmt.Sprintf("/api/v1/groups/%s/documents", groupID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Bob failed to get document: %d, %s", rec.Code, rec.Body.String())
	}

	// 4. Concurrency control: Bob tries to update with wrong expected_version (e.g. 99) -> 409 Conflict
	updateReq := map[string]interface{}{
		"expected_version":  99,
		"encrypted_content": "Modified content",
		"components":        map[string]string{"tableau1": "table"},
		"publish_type":      "IN_PLACE",
	}
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/documents/%s", groupID, docID), updateReq)
	if rec.Code != http.StatusConflict {
		t.Fatalf("Expected 409 Conflict on version mismatch, got %d", rec.Code)
	}

	// 5. Bob updates successfully with expected_version = 1 -> 200 OK (version increments to 2)
	updateReq["expected_version"] = 1
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/documents/%s", groupID, docID), updateReq)
	if rec.Code != http.StatusOK {
		t.Fatalf("Bob failed to update document: %d, %s", rec.Code, rec.Body.String())
	}
	var updateResp struct {
		Document documents.GroupDocument `json:"document"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &updateResp)
	if updateResp.Document.CurrentVersion != 2 {
		t.Fatalf("Expected version 2 after update, got %d", updateResp.Document.CurrentVersion)
	}

	// 6. Component Deletion Safeguard: Bob tries to delete referenced component "tableau1" without force -> 409 Conflict
	rec = bob.doRequest(t, http.MethodDelete, fmt.Sprintf("/api/v1/groups/%s/documents/%s/components/tableau1", groupID, docID), nil)
	// Notice in step 5, Bob updated content to "Modified content" which no longer references tableau1.
	// Let's first put content that references {{tableau1}} again with version 2
	refUpdateReq := map[string]interface{}{
		"expected_version":  2,
		"encrypted_content": "Voici le tableau: {{tableau1}}",
		"components":        map[string]string{"tableau1": "<table>data</table>"},
		"publish_type":      "IN_PLACE",
	}
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/documents/%s", groupID, docID), refUpdateReq)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to update with reference: %d", rec.Code)
	}

	// Now deleting tableau1 without force must return 409 Conflict
	rec = bob.doRequest(t, http.MethodDelete, fmt.Sprintf("/api/v1/groups/%s/documents/%s/components/tableau1", groupID, docID), nil)
	if rec.Code != http.StatusConflict {
		t.Fatalf("Expected 409 Conflict when deleting referenced component, got %d", rec.Code)
	}

	// Deleting with ?force=true must succeed
	rec = bob.doRequest(t, http.MethodDelete, fmt.Sprintf("/api/v1/groups/%s/documents/%s/components/tableau1?force=true", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to force delete component: %d, %s", rec.Code, rec.Body.String())
	}

	// 7. Role Management & Hierarchy:
	// Bob (MEMBER) tries to freeze document -> 403 Forbidden (only ADMIN/OWNER can freeze)
	rec = bob.doRequest(t, http.MethodPost, fmt.Sprintf("/api/v1/groups/%s/documents/%s/freeze", groupID, docID), nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("Expected 403 Forbidden for member freezing doc, got %d", rec.Code)
	}

	// Alice (OWNER) promotes Bob to ADMIN
	promoteReq := map[string]interface{}{"role": "ADMIN"}
	rec = alice.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/members/%s/role", groupID, bob.userID), promoteReq)
	if rec.Code != http.StatusOK {
		t.Fatalf("Alice failed to promote Bob: %d, %s", rec.Code, rec.Body.String())
	}

	// Bob is now ADMIN, Bob freezes document -> 200 OK
	rec = bob.doRequest(t, http.MethodPost, fmt.Sprintf("/api/v1/groups/%s/documents/%s/freeze", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Admin Bob failed to freeze doc: %d, %s", rec.Code, rec.Body.String())
	}

	// 8. Immutability when Frozen:
	// Bob (Admin) tries to edit frozen document -> 423 Locked
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/documents/%s", groupID, docID), refUpdateReq)
	if rec.Code != http.StatusLocked {
		t.Fatalf("Expected 423 Locked when modifying frozen doc, got %d", rec.Code)
	}

	// 9. Unfreeze & Restore Version:
	// Bob unfreezes document -> 200 OK
	rec = bob.doRequest(t, http.MethodPost, fmt.Sprintf("/api/v1/groups/%s/documents/%s/unfreeze", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to unfreeze: %d, %s", rec.Code, rec.Body.String())
	}

	// Check versions list
	rec = bob.doRequest(t, http.MethodGet, fmt.Sprintf("/api/v1/groups/%s/documents/%s/versions", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to get versions: %d", rec.Code)
	}
	var verResp struct {
		Versions []documents.DocumentVersion `json:"versions"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &verResp)
	if len(verResp.Versions) < 3 {
		t.Fatalf("Expected at least 3 versions in history, got %d", len(verResp.Versions))
	}

	// Restore version 1
	rec = bob.doRequest(t, http.MethodPost, fmt.Sprintf("/api/v1/groups/%s/documents/%s/restore/1", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to restore version 1: %d, %s", rec.Code, rec.Body.String())
	}

	// 10. Audit Logs:
	// Bob (Admin) checks audit logs -> 200 OK
	rec = bob.doRequest(t, http.MethodGet, fmt.Sprintf("/api/v1/groups/%s/documents/%s/audit", groupID, docID), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("Failed to get audit logs: %d", rec.Code)
	}
	var auditResp struct {
		AuditLogs []documents.AuditLog `json:"audit_logs"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &auditResp)
	if len(auditResp.AuditLogs) < 4 {
		t.Fatalf("Expected multiple audit logs, got %d", len(auditResp.AuditLogs))
	}

	// 11. Privilege Escalation Prevention:
	// Bob (ADMIN) tries to demote Alice (OWNER) -> 403 Forbidden (ErrOwnerImmutable)
	demoteReq := map[string]interface{}{"role": "MEMBER"}
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/members/%s/role", groupID, alice.userID), demoteReq)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("Security failure: Admin demoting Owner should return 403, got %d", rec.Code)
	}

	// 12. Anti-DoS Payload enforcement:
	hugeContent := strings.Repeat("A", 6*1024*1024) // 6MB > 5MB limit
	dosReq := map[string]interface{}{
		"expected_version":  4,
		"encrypted_content": hugeContent,
		"publish_type":      "IN_PLACE",
	}
	rec = bob.doRequest(t, http.MethodPut, fmt.Sprintf("/api/v1/groups/%s/documents/%s", groupID, docID), dosReq)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("Security failure: Document > 5MB should return 413 Request Entity Too Large, got %d", rec.Code)
	}
}
