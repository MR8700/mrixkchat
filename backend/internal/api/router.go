package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/messaging"
)

type Server struct {
	mux           *http.ServeMux
	idService     *identity.Service
	deviceService *devices.Service
	msgService    *messaging.Service
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
		repo:          repo,
	}
	s.routes()
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Global CORS and security headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-MRixk-Device-ID")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("X-XSS-Protection", "1; mode=block")

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
		"user":    user,
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
	UserID                 string `json:"user_id"`
	DeviceName             string `json:"device_name"`
	Platform               string `json:"platform"`
	IdentityPublicKey     string `json:"identity_public_key"`
	DiffieHellmanPublicKey string `json:"diffie_hellman_public_key"`
}

func (s *Server) handleAuthorizeDevice(w http.ResponseWriter, r *http.Request) {
	var req AuthorizeDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid request JSON payload")
		return
	}

	dev, token, err := s.deviceService.AuthorizeDevice(
		req.UserID, req.DeviceName, req.Platform, req.IdentityPublicKey, req.DiffieHellmanPublicKey,
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
