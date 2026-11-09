package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/messaging"
)

func setupTestServer() *Server {
	repo := database.NewMemoryRepository(3)
	idService := identity.NewService(repo)
	deviceService := devices.NewService(repo)
	msgService := messaging.NewService(repo)
	return NewServer(idService, deviceService, msgService, repo)
}

func TestAPI_FullEndToEndFlow(t *testing.T) {
	server := setupTestServer()

	// 1. Healthcheck
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Healthcheck failed, got code %d", rec.Code)
	}

	// 2. Register user
	regPayload := `{"handle":"@mrixk.richard","password":"mypassword2026","display_name":"Richard MARE"}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewBufferString(regPayload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Register failed: code %d, body: %s", rec.Code, rec.Body.String())
	}

	var regResp struct {
		User database.User `json:"user"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &regResp); err != nil {
		t.Fatalf("Failed to parse register response: %v", err)
	}
	userID := regResp.User.ID

	// Duplicate registration must return 409 Conflict
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewBufferString(regPayload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("Expected 409 Conflict for duplicate handle, got %d", rec.Code)
	}

	// 3. Authorize Device 1 (Android)
	dev1Payload := fmt.Sprintf(`{"user_id":"%s","device_name":"Pixel Phone","platform":"Android","identity_public_key":"pub1","diffie_hellman_public_key":"dh1"}`, userID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev1Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Authorize Device 1 failed: code %d, body: %s", rec.Code, rec.Body.String())
	}
	var dev1Resp struct {
		Device       database.Device `json:"device"`
		SessionToken string          `json:"session_token"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &dev1Resp)
	token1 := dev1Resp.SessionToken

	// 4. Authorize Device 2 (Windows)
	dev2Payload := fmt.Sprintf(`{"user_id":"%s","device_name":"Work PC","platform":"Windows","identity_public_key":"pub2","diffie_hellman_public_key":"dh2"}`, userID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev2Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Authorize Device 2 failed: %d", rec.Code)
	}
	var dev2Resp struct {
		Device database.Device `json:"device"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &dev2Resp)
	dev2ID := dev2Resp.Device.ID

	// 5. Authorize Device 3 (Linux)
	dev3Payload := fmt.Sprintf(`{"user_id":"%s","device_name":"Parrot Laptop","platform":"Linux","identity_public_key":"pub3","diffie_hellman_public_key":"dh3"}`, userID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev3Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Authorize Device 3 failed: %d", rec.Code)
	}

	// 6. ATTEMPT 4TH DEVICE AUTHORIZATION -> MUST RETURN 403 FORBIDDEN
	dev4Payload := fmt.Sprintf(`{"user_id":"%s","device_name":"Extra iPad","platform":"iOS","identity_public_key":"pub4","diffie_hellman_public_key":"dh4"}`, userID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev4Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("Security failure: 4th device was NOT rejected with 403 Forbidden! Got: %d, body: %s", rec.Code, rec.Body.String())
	}

	// 7. List devices using Device 1 token
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/devices", nil)
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("List devices failed: %d", rec.Code)
	}

	// 8. Create Conversation
	convPayload := `{"type":"DIRECT","title":"Secure Channel","members":[]}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/conversations", bytes.NewBufferString(convPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Create conversation failed: %d, body: %s", rec.Code, rec.Body.String())
	}
	var convResp struct {
		Conversation database.Conversation `json:"conversation"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &convResp)
	convID := convResp.Conversation.ID

	// 9. Send Encrypted Message Envelope
	msgPayload := fmt.Sprintf(`{"conversation_id":"%s","ciphertext":"BASE64_E2EE_CIPHERTEXT_123456","idempotency_key":"idem-uuid-001","protocol_version":1}`, convID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/messages", bytes.NewBufferString(msgPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Send encrypted message failed: %d, body: %s", rec.Code, rec.Body.String())
	}

	// 10. Fetch Sync Events
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/sync/events?cursor=0", nil)
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Fetch sync events failed: %d", rec.Code)
	}
	var syncResp struct {
		Events []*database.SyncEvent `json:"events"`
		Count  int                   `json:"count"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &syncResp)
	if syncResp.Count != 1 {
		t.Fatalf("Expected 1 sync event, got %d", syncResp.Count)
	}

	// 11. Revoke Device 2
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/devices/"+dev2ID, nil)
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Revoke device failed: %d, body: %s", rec.Code, rec.Body.String())
	}

	// 12. Now retry adding the 4th device (now takes the 3rd available active slot) -> MUST SUCCEED
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev4Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for re-attempted device after revocation, got: %d", rec.Code)
	}
}
