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

	// 3. Unauthorized Device Authorization attempt (no credentials or session) -> MUST RETURN 401
	unauthDevPayload := fmt.Sprintf(`{"user_id":"%s","device_name":"Attacker Phone","platform":"Android"}`, userID)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(unauthDevPayload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("Security failure: unauthenticated device authorization should return 401, got: %d", rec.Code)
	}

	// 3b. Authorize Device 1 (Android) with valid password credentials
	dev1Payload := fmt.Sprintf(`{"user_id":"%s","password":"mypassword2026","device_name":"Pixel Phone","platform":"Android","identity_public_key":"pub1","diffie_hellman_public_key":"dh1"}`, userID)
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

	// 4. Authorize Device 2 (Windows) authenticated via Device 1's active session token
	dev2Payload := fmt.Sprintf(`{"device_name":"Work PC","platform":"Windows","identity_public_key":"pub2","diffie_hellman_public_key":"dh2"}`)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev2Payload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Authorize Device 2 failed: %d, body: %s", rec.Code, rec.Body.String())
	}
	var dev2Resp struct {
		Device database.Device `json:"device"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &dev2Resp)
	dev2ID := dev2Resp.Device.ID

	// 5. Authorize Device 3 (Linux) authenticated via user password
	dev3Payload := fmt.Sprintf(`{"handle":"@mrixk.richard","password":"mypassword2026","device_name":"Parrot Laptop","platform":"Linux","identity_public_key":"pub3","diffie_hellman_public_key":"dh3"}`)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/devices/authorize", bytes.NewBufferString(dev3Payload))
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Authorize Device 3 failed: %d, body: %s", rec.Code, rec.Body.String())
	}

	// 6. ATTEMPT 4TH DEVICE AUTHORIZATION -> MUST RETURN 403 FORBIDDEN (quota exceeded)
	dev4Payload := fmt.Sprintf(`{"user_id":"%s","password":"mypassword2026","device_name":"Extra iPad","platform":"iOS","identity_public_key":"pub4","diffie_hellman_public_key":"dh4"}`, userID)
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

	// 13. Test Encrypted Media Upload & Download
	mediaPayload := []byte("ENCRYPTED_BLOB_IMAGE_CONTENT_AES_GCM")
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/media/upload", bytes.NewBuffer(mediaPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	req.Header.Set("X-Media-ID", "media_test_001")
	req.Header.Set("Content-Type", "image/jpeg")
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Media upload failed: %d, body: %s", rec.Code, rec.Body.String())
	}

	// Unauthenticated media download attempt -> MUST RETURN 401
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/media/media_test_001", nil)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("Security failure: unauthenticated media download should return 401, got: %d", rec.Code)
	}

	// Download the uploaded media with valid session
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/media/media_test_001", nil)
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Authenticated media download failed: %d", rec.Code)
	}
	if !bytes.Equal(rec.Body.Bytes(), mediaPayload) {
		t.Fatalf("Downloaded media payload mismatch")
	}

	// 14. Test WebRTC Call Offer Signaling
	callOfferPayload := `{"call_id":"call_001","callee_id":"user_sophie","type":"AUDIO","sdp_offer":"v=0\r\no=- 42 2 IN IP4 127.0.0.1"}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/calls/offer", bytes.NewBufferString(callOfferPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Call offer failed: %d", rec.Code)
	}

	// 15. Test Moments Feed
	momentPayload := `{"id":"moment_001","type":"image","media_url":"https://example.com/moment.jpg","text":"Beau coucher de soleil !"}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/moments", bytes.NewBufferString(momentPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("Create moment failed: %d", rec.Code)
	}

	// Unauthenticated moments list attempt -> MUST RETURN 401
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/moments", nil)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("Security failure: unauthenticated moments list should return 401, got: %d", rec.Code)
	}

	// Authenticated moments list
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/moments", nil)
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("List moments failed: %d", rec.Code)
	}

	// 16. Test Local AI Query Endpoint
	aiQueryPayload := `{"prompt":"Quelles sont mes préférences de confidentialité ?"}`
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/v1/ai/query", bytes.NewBufferString(aiQueryPayload))
	req.Header.Set("Authorization", "Bearer "+token1)
	server.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("AI query failed: %d", rec.Code)
	}
}
