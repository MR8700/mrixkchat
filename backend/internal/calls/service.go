package calls

import (
	"errors"
	"sync"
	"time"
)

var (
	ErrCallNotFound = errors.New("call session not found")
	ErrCallInactive = errors.New("call session is no longer active")
)

type CallType string

const (
	CallTypeAudio CallType = "AUDIO"
	CallTypeVideo CallType = "VIDEO"
)

type CallStatus string

const (
	CallStatusRinging   CallStatus = "RINGING"
	CallStatusConnected CallStatus = "CONNECTED"
	CallStatusEnded     CallStatus = "ENDED"
	CallStatusDeclined  CallStatus = "DECLINED"
)

// CallSession represents an active peer-to-peer WebRTC call session.
type CallSession struct {
	ID          string     `json:"id"`
	CallerID    string     `json:"caller_id"`
	CallerDevID string     `json:"caller_device_id"`
	CalleeID    string     `json:"callee_id"`
	Type        CallType   `json:"type"`
	Status      CallStatus `json:"status"`
	SDPOffer    string     `json:"sdp_offer,omitempty"`
	SDPAnswer   string     `json:"sdp_answer,omitempty"`
	StartedAt   time.Time  `json:"started_at"`
	EndedAt     *time.Time `json:"ended_at,omitempty"`
}

type Service struct {
	calls map[string]*CallSession
	mu    sync.RWMutex
}

func NewService() *Service {
	return &Service{
		calls: make(map[string]*CallSession),
	}
}

// InitiateCall creates a new WebRTC call offer.
func (s *Service) InitiateCall(callID, callerID, callerDevID, calleeID string, callType CallType, sdpOffer string) *CallSession {
	s.mu.Lock()
	defer s.mu.Unlock()

	session := &CallSession{
		ID:          callID,
		CallerID:    callerID,
		CallerDevID: callerDevID,
		CalleeID:    calleeID,
		Type:        callType,
		Status:      CallStatusRinging,
		SDPOffer:    sdpOffer,
		StartedAt:   time.Now(),
	}
	s.calls[callID] = session
	return session
}

// AnswerCall records the callee's SDP answer and transitions to connected.
func (s *Service) AnswerCall(callID string, sdpAnswer string) (*CallSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	call, exists := s.calls[callID]
	if !exists {
		return nil, ErrCallNotFound
	}
	if call.Status != CallStatusRinging {
		return nil, ErrCallInactive
	}

	call.SDPAnswer = sdpAnswer
	call.Status = CallStatusConnected
	return call, nil
}

// EndCall terminates the call session.
func (s *Service) EndCall(callID string) (*CallSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	call, exists := s.calls[callID]
	if !exists {
		return nil, ErrCallNotFound
	}

	now := time.Now()
	call.EndedAt = &now
	call.Status = CallStatusEnded
	return call, nil
}

// GetCall returns the current state of a call.
func (s *Service) GetCall(callID string) (*CallSession, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	call, exists := s.calls[callID]
	if !exists {
		return nil, ErrCallNotFound
	}
	return call, nil
}
