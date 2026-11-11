package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"mrixk.io/mrixk/backend/internal/ai"
	"mrixk.io/mrixk/backend/internal/calls"
	"mrixk.io/mrixk/backend/internal/contacts"
	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/documents"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/media"
	"mrixk.io/mrixk/backend/internal/messaging"
	"mrixk.io/mrixk/backend/internal/social"
)

type Server struct {
	mux           *http.ServeMux
	idService     *identity.Service
	deviceService *devices.Service
	msgService    *messaging.Service
	callService   *calls.Service
	mediaService  *media.Service
	socialService *social.Service
	contactService *contacts.Service
	aiService     *ai.Service
	docService    *documents.Service
	hub           *Hub
	repo          *database.MemoryRepository
}

func NewServer(
	idService *identity.Service,
	deviceService *devices.Service,
	msgService *messaging.Service,
	repo *database.MemoryRepository,
) *Server {
	s := &Server{
		mux:           http.NewServeMux(),
		idService:     idService,
		deviceService: deviceService,
		msgService:    msgService,
		callService:   calls.NewService(),
		mediaService:  media.NewService(),
		socialService: social.NewService(),
		contactService: contacts.NewService(),
		aiService:     ai.NewService(),
		docService:    documents.NewService(),
		hub:           NewHub(),
		repo:          repo,
	}
	s.routes()
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Global CORS and security headers
	origin := r.Header.Get("Origin")
	if origin != "" {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Vary", "Origin")
	} else {
		w.Header().Set("Access-Control-Allow-Origin", "*")
	}
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-MRixk-Device-ID, X-Media-ID, X-Media-SHA256")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("X-XSS-Protection", "1; mode=block")
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	s.mux.ServeHTTP(w, r)
}

func (s *Server) routes() {
	// Health & Diagnostics
	s.mux.HandleFunc("GET /api/v1/health", s.handleHealth)

	// Auth & Identity
	s.mux.HandleFunc("POST /api/v1/auth/register", s.handleRegister)
	s.mux.HandleFunc("POST /api/v1/auth/login", s.handleLogin)

	// Devices (Max 3 limit enforced)
	s.mux.HandleFunc("POST /api/v1/devices/authorize", s.handleAuthorizeDevice)
	s.mux.HandleFunc("GET /api/v1/devices", s.handleListDevices)
	s.mux.HandleFunc("DELETE /api/v1/devices/{id}", s.handleRevokeDevice)

	// Messaging & E2EE Envelopes
	s.mux.HandleFunc("POST /api/v1/conversations", s.handleCreateConversation)
	s.mux.HandleFunc("POST /api/v1/messages", s.handleSendMessage)

	// Synchronization
	s.mux.HandleFunc("GET /api/v1/sync/events", s.handleGetSyncEvents)

	// Real-time WebSocket Stream
	s.mux.HandleFunc("GET /api/v1/ws", s.handleWebSocket)

	// WebRTC Calls Signaling
	s.mux.HandleFunc("POST /api/v1/calls/offer", s.handleCallOffer)
	s.mux.HandleFunc("POST /api/v1/calls/answer", s.handleCallAnswer)
	s.mux.HandleFunc("POST /api/v1/calls/hangup", s.handleCallHangup)

	// Encrypted Media Attachments Relay
	s.mux.HandleFunc("POST /api/v1/media/upload", s.handleMediaUpload)
	s.mux.HandleFunc("GET /api/v1/media/{id}", s.handleMediaDownload)

	// Social & Moments Feed
	s.mux.HandleFunc("GET /api/v1/moments", s.handleListMoments)
	s.mux.HandleFunc("POST /api/v1/moments", s.handleCreateMoment)

	// Contacts Discovery
	s.mux.HandleFunc("GET /api/v1/contacts", s.handleListContacts)

	// AI Local Cognitive Query
	s.mux.HandleFunc("POST /api/v1/ai/query", s.handleAIQuery)

	// Collaborative Bloc-Note & Group Workspaces (E2EE)
	s.mux.HandleFunc("POST /api/v1/groups/{id}/documents", s.handleCreateGroupDocument)
	s.mux.HandleFunc("GET /api/v1/groups/{id}/documents", s.handleGetGroupDocument)
	s.mux.HandleFunc("PUT /api/v1/groups/{id}/documents/{docId}", s.handleUpdateGroupDocument)
	s.mux.HandleFunc("POST /api/v1/groups/{id}/documents/{docId}/freeze", s.handleFreezeGroupDocument)
	s.mux.HandleFunc("POST /api/v1/groups/{id}/documents/{docId}/unfreeze", s.handleUnfreezeGroupDocument)
	s.mux.HandleFunc("GET /api/v1/groups/{id}/documents/{docId}/versions", s.handleGetGroupDocumentVersions)
	s.mux.HandleFunc("POST /api/v1/groups/{id}/documents/{docId}/restore/{version}", s.handleRestoreGroupDocumentVersion)
	s.mux.HandleFunc("DELETE /api/v1/groups/{id}/documents/{docId}/components/{name}", s.handleDeleteGroupDocumentComponent)
	s.mux.HandleFunc("PUT /api/v1/groups/{id}/members/{userId}/role", s.handleAssignGroupMemberRole)
	s.mux.HandleFunc("GET /api/v1/groups/{id}/documents/{docId}/audit", s.handleGetGroupDocumentAuditLogs)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":    "healthy",
		"service":   "mrixk-backend",
		"version":   "1.0.0",
		"timestamp": r.Context().Value("time"),
	})
}

type RegisterRequest struct {
	Handle            string `json:"handle"`
	Password          string `json:"password"`
	DisplayName       string `json:"display_name"`
	RecoveryPublicKey string `json:"recovery_public_key"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	user, err := s.idService.Register(req.Handle, req.Password, req.RecoveryPublicKey, req.DisplayName)
	if err != nil {
		if errors.Is(err, database.ErrHandleAlreadyTaken) {
			jsonError(w, http.StatusConflict, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"message": "User registered successfully",
		"user":    user.Public(),
	})
}

type LoginRequest struct {
	Handle   string `json:"handle"`
	Password string `json:"password"`
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	user, err := s.idService.Authenticate(req.Handle, req.Password)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message": "Authentication successful",
		"user_id": user.ID,
		"handle":  user.Handle,
	})
}

type AuthorizeDeviceRequest struct {
	UserID                 string `json:"user_id,omitempty"`
	Handle                 string `json:"handle,omitempty"`
	Password               string `json:"password,omitempty"`
	DeviceName             string `json:"device_name"`
	Platform               string `json:"platform"`
	IdentityPublicKey     string `json:"identity_public_key,omitempty"`
	DiffieHellmanPublicKey string `json:"diffie_hellman_public_key,omitempty"`
}

func (s *Server) handleAuthorizeDevice(w http.ResponseWriter, r *http.Request) {
	var req AuthorizeDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	targetUserID := req.UserID

	// 1. Authenticate the authorization request
	existingDev, authErr := s.authenticateDeviceSession(r)
	if authErr == nil && existingDev != nil {
		targetUserID = existingDev.UserID
	} else if req.Password != "" {
		if req.Handle != "" {
			user, err := s.idService.Authenticate(req.Handle, req.Password)
			if err != nil {
				jsonError(w, http.StatusUnauthorized, "Authentication failed: invalid handle or password")
				return
			}
			targetUserID = user.ID
		} else if targetUserID != "" {
			user, err := s.repo.GetUserByID(targetUserID)
			if err != nil || !s.idService.VerifyUserPassword(user, req.Password) {
				jsonError(w, http.StatusUnauthorized, "Authentication failed: invalid user ID or password")
				return
			}
		} else {
			jsonError(w, http.StatusBadRequest, "Missing handle or user_id for password authentication")
			return
		}
	} else {
		jsonError(w, http.StatusUnauthorized, "Unauthorized: password or existing device session token required to authorize a device")
		return
	}

	// 2. Fallback key generation if client did not supply pre-generated keys
	idKey := req.IdentityPublicKey
	dhKey := req.DiffieHellmanPublicKey
	if idKey == "" {
		idKey = fmt.Sprintf("auto-id-key-%s-%d", req.Platform, time.Now().UnixNano())
	}
	if dhKey == "" {
		dhKey = fmt.Sprintf("auto-dh-key-%s-%d", req.Platform, time.Now().UnixNano())
	}

	dev, token, err := s.deviceService.AuthorizeDevice(
		targetUserID, req.DeviceName, req.Platform, idKey, dhKey,
	)
	if err != nil {
		if errors.Is(err, database.ErrMaxDevicesExceeded) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"message":       "Device authorized successfully",
		"device":        dev,
		"session_token": token,
	})
}

func (s *Server) handleListDevices(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	list := s.deviceService.ListDevices(dev.UserID)
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"devices": list,
	})
}

func (s *Server) handleRevokeDevice(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	targetDeviceID := r.PathValue("id")
	if targetDeviceID == "" {
		jsonError(w, http.StatusBadRequest, "Device ID required in path")
		return
	}

	if err := s.deviceService.RevokeDevice(dev.UserID, targetDeviceID); err != nil {
		jsonError(w, http.StatusNotFound, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message": "Device revoked successfully",
		"id":      targetDeviceID,
	})
}

type CreateConversationRequest struct {
	Type    string   `json:"type"` // DIRECT, GROUP
	Title   string   `json:"title"`
	Members []string `json:"members"`
}

func (s *Server) handleCreateConversation(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req CreateConversationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	// Ensure caller is in members
	members := append(req.Members, dev.UserID)
	conv, err := s.msgService.CreateConversation(req.Type, req.Title, dev.UserID, members)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"conversation": conv,
	})
}

type SendMessageRequest struct {
	ConversationID  string `json:"conversation_id"`
	Ciphertext      string `json:"ciphertext"`
	IdempotencyKey  string `json:"idempotency_key"`
	ProtocolVersion int    `json:"protocol_version"`
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	msg, err := s.msgService.SendEncryptedEnvelope(
		req.ConversationID,
		dev.UserID,
		dev.ID,
		req.Ciphertext,
		req.IdempotencyKey,
		req.ProtocolVersion,
	)
	if err != nil {
		if errors.Is(err, database.ErrConversationNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Broadcast real-time message envelope to conversation participants via WebSocket
	conv, _ := s.repo.GetConversation(req.ConversationID)
	if conv != nil {
		for _, memberID := range conv.Members {
			if memberID != dev.UserID {
				s.hub.BroadcastToUser(memberID, &WSEvent{
					Type:      "ENVELOPE",
					Payload:   msg,
					Timestamp: time.Now(),
				}, "")
			}
		}
	}

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"message": msg,
	})
}

func (s *Server) handleGetSyncEvents(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	cursorStr := r.URL.Query().Get("cursor")
	var cursor int64
	if cursorStr != "" {
		cursor, _ = strconv.ParseInt(cursorStr, 10, 64)
	}

	events := s.msgService.GetSyncEvents(dev.UserID, cursor)
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"events": events,
		"count":  len(events),
	})
}

func (s *Server) authenticateDeviceSession(r *http.Request) (*database.Device, error) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return nil, errors.New("missing Authorization header")
	}

	token := strings.TrimPrefix(authHeader, "Bearer ")
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, errors.New("empty bearer token")
	}

	dev, _, err := s.deviceService.ValidateSession(token)
	if err != nil {
		return nil, err
	}
	return dev, nil
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	// Accept token from Authorization header or ?token= query parameter
	token := r.URL.Query().Get("token")
	if token == "" {
		authHeader := r.Header.Get("Authorization")
		token = strings.TrimPrefix(authHeader, "Bearer ")
		token = strings.TrimSpace(token)
	}

	if token == "" {
		http.Error(w, "Unauthorized: missing session token", http.StatusUnauthorized)
		return
	}

	dev, _, err := s.deviceService.ValidateSession(token)
	if err != nil {
		http.Error(w, "Unauthorized: invalid session token", http.StatusUnauthorized)
		return
	}

	conn, bufrw, err := UpgradeToWebSocket(w, r)
	if err != nil {
		log.Printf("[WebSocket Upgrade Error] %v", err)
		return
	}

	s.hub.HandleWebSocketConnection(dev.UserID, dev.ID, conn, bufrw)
}

func (s *Server) handleCallOffer(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req struct {
		CallID   string `json:"call_id"`
		CalleeID string `json:"callee_id"`
		Type     string `json:"type"`
		SDPOffer string `json:"sdp_offer"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	callType := calls.CallTypeAudio
	if req.Type == "VIDEO" {
		callType = calls.CallTypeVideo
	}

	session := s.callService.InitiateCall(req.CallID, dev.UserID, dev.ID, req.CalleeID, callType, req.SDPOffer)

	// Broadcast call offer in real time over WebSocket to all of callee's active devices
	s.hub.BroadcastToUser(req.CalleeID, &WSEvent{
		Type:      "CALL_OFFER",
		Payload:   session,
		Timestamp: time.Now(),
	}, "")

	jsonResponse(w, http.StatusCreated, session)
}

func (s *Server) handleCallAnswer(w http.ResponseWriter, r *http.Request) {
	_, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req struct {
		CallID    string `json:"call_id"`
		SDPAnswer string `json:"sdp_answer"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	session, err := s.callService.AnswerCall(req.CallID, req.SDPAnswer)
	if err != nil {
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	s.hub.BroadcastToUser(session.CallerID, &WSEvent{
		Type:      "CALL_ANSWER",
		Payload:   session,
		Timestamp: time.Now(),
	}, "")

	jsonResponse(w, http.StatusOK, session)
}

func (s *Server) handleCallHangup(w http.ResponseWriter, r *http.Request) {
	_, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req struct {
		CallID string `json:"call_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	session, err := s.callService.EndCall(req.CallID)
	if err != nil {
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	ev := &WSEvent{
		Type:      "CALL_HANGUP",
		Payload:   session,
		Timestamp: time.Now(),
	}
	s.hub.BroadcastToUser(session.CallerID, ev, "")
	s.hub.BroadcastToUser(session.CalleeID, ev, "")

	jsonResponse(w, http.StatusOK, session)
}

func (s *Server) handleMediaUpload(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	// Protect against unbounded payload DoS / memory exhaustion
	r.Body = http.MaxBytesReader(w, r.Body, media.MaxMediaBytes)
	data, err := io.ReadAll(r.Body)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "Failed to read payload or payload exceeds maximum allowed size (100MB)")
		return
	}

	id := r.Header.Get("X-Media-ID")
	if id == "" {
		id = fmt.Sprintf("media-%d", time.Now().UnixNano())
	}
	expectedHash := r.Header.Get("X-Media-SHA256")
	mimeType := r.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	blob, err := s.mediaService.StoreBlob(id, dev.UserID, expectedHash, mimeType, data, 0)
	if err != nil {
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, blob)
}

func (s *Server) handleMediaDownload(w http.ResponseWriter, r *http.Request) {
	_, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, "Authentication required to download media: "+err.Error())
		return
	}

	mediaID := r.PathValue("id")
	if mediaID == "" {
		jsonError(w, http.StatusBadRequest, "Missing media id")
		return
	}

	blob, err := s.mediaService.GetBlob(mediaID)
	if err != nil {
		jsonError(w, http.StatusNotFound, err.Error())
		return
	}

	w.Header().Set("Content-Type", blob.MimeType)
	w.Header().Set("Content-Length", strconv.FormatInt(blob.SizeBytes, 10))
	w.Header().Set("X-Media-SHA256", blob.SHA256Hash)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(blob.Data)
}

func (s *Server) handleListMoments(w http.ResponseWriter, r *http.Request) {
	_, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, "Authentication required to view moments")
		return
	}

	moments := s.socialService.GetActiveMoments()
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"moments": moments,
		"count":   len(moments),
	})
}

func (s *Server) handleCreateMoment(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req struct {
		ID       string `json:"id"`
		Type     string `json:"type"`
		MediaURL string `json:"media_url"`
		Text     string `json:"text"`
		Duration string `json:"duration"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid payload")
		return
	}

	u, _ := s.repo.GetUserByID(dev.UserID)
	displayName := "Utilisateur"
	handle := "@user"
	if u != nil {
		displayName = u.DisplayName
		handle = u.Handle
	}

	moment := s.socialService.CreateMoment(
		req.ID,
		dev.UserID,
		displayName,
		handle,
		req.Type,
		req.MediaURL,
		req.Text,
		req.Duration,
		0,
	)

	jsonResponse(w, http.StatusCreated, moment)
}

func (s *Server) handleListContacts(w http.ResponseWriter, r *http.Request) {
	_, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	contacts := s.contactService.Search("")
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"contacts": contacts,
		"count":    len(contacts),
	})
}

func (s *Server) handleAIQuery(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	var req struct {
		Prompt string `json:"prompt"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid query payload")
		return
	}

	res, err := s.aiService.ProcessQuery(ai.AIQueryRequest{
		UserID: dev.UserID,
		Prompt: req.Prompt,
	})
	if err != nil {
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, res)
}

// -----------------------------------------------------------------------------
// Group Documents & Collaborative Bloc-Note Handlers (Lot S1 / E2EE)
// -----------------------------------------------------------------------------

func (s *Server) ensureGroupMemberRoles(groupID string, callerID string) error {
	conv, err := s.repo.GetConversation(groupID)
	if err != nil {
		if errors.Is(err, database.ErrConversationNotFound) {
			return errors.New("group conversation not found")
		}
		return err
	}

	isMember := false
	for _, m := range conv.Members {
		if m == callerID {
			isMember = true
			break
		}
	}
	if !isMember && callerID != conv.CreatedBy {
		return documents.ErrNotGroupMember
	}

	// Initialize group roles in docService if not present
	if _, exists := s.docService.GetMemberRole(groupID, conv.CreatedBy); !exists {
		s.docService.SetMemberRole(groupID, conv.CreatedBy, documents.RoleOwner)
		for _, m := range conv.Members {
			if m != conv.CreatedBy {
				if _, hasRole := s.docService.GetMemberRole(groupID, m); !hasRole {
					s.docService.SetMemberRole(groupID, m, documents.RoleMember)
				}
			}
		}
	} else {
		if _, exists := s.docService.GetMemberRole(groupID, callerID); !exists {
			s.docService.SetMemberRole(groupID, callerID, documents.RoleMember)
		}
	}

	return nil
}

type CreateDocumentRequest struct {
	Title            string            `json:"title"`
	EncryptedContent string            `json:"encrypted_content"`
	Components       map[string]string `json:"components"`
	LineSpacing      float64           `json:"line_spacing"`
	ParagraphSpacing float64           `json:"paragraph_spacing"`
}

func (s *Server) handleCreateGroupDocument(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	if groupID == "" {
		jsonError(w, http.StatusBadRequest, "Missing group ID")
		return
	}

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		if errors.Is(err, documents.ErrNotGroupMember) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		jsonError(w, http.StatusNotFound, err.Error())
		return
	}

	var req CreateDocumentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	doc, err := s.docService.CreateDocument(
		dev.UserID, groupID, req.Title, req.EncryptedContent,
		req.Components, req.LineSpacing, req.ParagraphSpacing,
	)
	if err != nil {
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentTooLarge) || errors.Is(err, documents.ErrComponentTooLarge) || errors.Is(err, documents.ErrTooManyComponents) {
			jsonError(w, http.StatusRequestEntityTooLarge, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"document": doc,
	})
}

func (s *Server) handleGetGroupDocument(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		if errors.Is(err, documents.ErrNotGroupMember) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		jsonError(w, http.StatusNotFound, err.Error())
		return
	}

	doc, err := s.docService.GetDocument(dev.UserID, groupID)
	if err != nil {
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		if errors.Is(err, documents.ErrNotGroupMember) || errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"document": doc,
	})
}

type UpdateDocumentRequest struct {
	ExpectedVersion  int               `json:"expected_version"`
	EncryptedContent string            `json:"encrypted_content"`
	Components       map[string]string `json:"components"`
	LineSpacing      float64           `json:"line_spacing"`
	ParagraphSpacing float64           `json:"paragraph_spacing"`
	PublishType      string            `json:"publish_type"`
}

func (s *Server) handleUpdateGroupDocument(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		if errors.Is(err, documents.ErrNotGroupMember) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		jsonError(w, http.StatusNotFound, err.Error())
		return
	}

	var req UpdateDocumentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	pubType := documents.PublishInPlace
	if req.PublishType == string(documents.PublishPostToChat) {
		pubType = documents.PublishPostToChat
	}

	doc, ver, err := s.docService.UpdateDocument(
		dev.UserID, groupID, docID,
		req.ExpectedVersion, req.EncryptedContent,
		req.Components, req.LineSpacing, req.ParagraphSpacing,
		pubType,
	)
	if err != nil {
		if errors.Is(err, documents.ErrDocumentFrozen) {
			jsonError(w, http.StatusLocked, err.Error())
			return
		}
		if errors.Is(err, documents.ErrConcurrentModification) {
			jsonError(w, http.StatusConflict, err.Error())
			return
		}
		if errors.Is(err, documents.ErrPermissionDenied) || errors.Is(err, documents.ErrNotGroupMember) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentTooLarge) || errors.Is(err, documents.ErrComponentTooLarge) || errors.Is(err, documents.ErrTooManyComponents) {
			jsonError(w, http.StatusRequestEntityTooLarge, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"document": doc,
		"version":  ver,
	})
}

func (s *Server) handleFreezeGroupDocument(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	if err := s.docService.FreezeDocument(dev.UserID, groupID, docID); err != nil {
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message": "Document frozen in read-only mode by administrator",
		"doc_id":  docID,
		"state":   "FROZEN",
	})
}

func (s *Server) handleUnfreezeGroupDocument(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	if err := s.docService.UnfreezeDocument(dev.UserID, groupID, docID); err != nil {
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message": "Document unfrozen successfully",
		"doc_id":  docID,
		"state":   "ACTIVE",
	})
}

func (s *Server) handleGetGroupDocumentVersions(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	versions, err := s.docService.GetVersions(dev.UserID, groupID, docID)
	if err != nil {
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"versions": versions,
	})
}

func (s *Server) handleRestoreGroupDocumentVersion(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")
	verStr := r.PathValue("version")
	targetVersion, err := strconv.Atoi(verStr)
	if err != nil || targetVersion <= 0 {
		jsonError(w, http.StatusBadRequest, "Invalid version number")
		return
	}

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	doc, err := s.docService.RestoreVersion(dev.UserID, groupID, docID, targetVersion)
	if err != nil {
		if errors.Is(err, documents.ErrDocumentFrozen) {
			jsonError(w, http.StatusLocked, err.Error())
			return
		}
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"document": doc,
		"message":  fmt.Sprintf("Document restored from version %d", targetVersion),
	})
}

func (s *Server) handleDeleteGroupDocumentComponent(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")
	compName := r.PathValue("name")
	force := r.URL.Query().Get("force") == "true"

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	if err := s.docService.DeleteComponent(dev.UserID, groupID, docID, compName, force); err != nil {
		if errors.Is(err, documents.ErrDocumentFrozen) {
			jsonError(w, http.StatusLocked, err.Error())
			return
		}
		if errors.Is(err, documents.ErrComponentReferenced) {
			jsonError(w, http.StatusConflict, err.Error())
			return
		}
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message":   "Component deleted successfully",
		"component": compName,
	})
}

type AssignRoleRequest struct {
	Role string `json:"role"`
}

func (s *Server) handleAssignGroupMemberRole(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	targetUserID := r.PathValue("userId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	var req AssignRoleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	role := documents.Role(req.Role)
	if err := s.docService.AssignMemberRole(dev.UserID, groupID, targetUserID, role); err != nil {
		if errors.Is(err, documents.ErrOwnerImmutable) || errors.Is(err, documents.ErrInvalidRoleHierarchy) || errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrNotGroupMember) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"message": "Role assigned successfully",
		"user_id": targetUserID,
		"role":    string(role),
	})
}

func (s *Server) handleGetGroupDocumentAuditLogs(w http.ResponseWriter, r *http.Request) {
	dev, err := s.authenticateDeviceSession(r)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, err.Error())
		return
	}

	groupID := r.PathValue("id")
	docID := r.PathValue("docId")

	if err := s.ensureGroupMemberRoles(groupID, dev.UserID); err != nil {
		jsonError(w, http.StatusForbidden, err.Error())
		return
	}

	logs, err := s.docService.GetAuditLogs(dev.UserID, groupID, docID)
	if err != nil {
		if errors.Is(err, documents.ErrPermissionDenied) {
			jsonError(w, http.StatusForbidden, err.Error())
			return
		}
		if errors.Is(err, documents.ErrDocumentNotFound) {
			jsonError(w, http.StatusNotFound, err.Error())
			return
		}
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"audit_logs": logs,
	})
}

func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, status int, message string) {
	jsonResponse(w, status, map[string]string{
		"error": message,
	})
}
