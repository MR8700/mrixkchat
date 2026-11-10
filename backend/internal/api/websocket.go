package api

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"sync"
	"time"
)

const (
	websocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
)

// WSEvent defines a real-time event envelope transmitted over WebSocket.
type WSEvent struct {
	Type      string      `json:"type"` // "ENVELOPE", "RECEIPT", "PRESENCE", "CALL_SIGNAL"
	Payload   interface{} `json:"payload"`
	Timestamp time.Time   `json:"timestamp"`
}

// ClientConnection represents an authenticated, active device connection.
type ClientConnection struct {
	UserID   string
	DeviceID string
	conn     net.Conn
	bufrw    *bufio.ReadWriter
	sendChan chan []byte
	closed   bool
	mu       sync.Mutex
}

// Hub manages active WebSocket connections for users and devices.
type Hub struct {
	// userID -> deviceID -> ClientConnection
	clients map[string]map[string]*ClientConnection
	mu      sync.RWMutex
}

// NewHub instantiates a real-time messaging hub.
func NewHub() *Hub {
	return &Hub{
		clients: make(map[string]map[string]*ClientConnection),
	}
}

// Register adds an active client connection.
func (h *Hub) Register(c *ClientConnection) {
	h.mu.Lock()
	defer h.mu.Unlock()

	userDevs, exists := h.clients[c.UserID]
	if !exists {
		userDevs = make(map[string]*ClientConnection)
		h.clients[c.UserID] = userDevs
	}
	userDevs[c.DeviceID] = c
}

// Unregister removes a client connection.
func (h *Hub) Unregister(userID, deviceID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if userDevs, exists := h.clients[userID]; exists {
		if c, ok := userDevs[deviceID]; ok {
			c.Close()
			delete(userDevs, deviceID)
		}
		if len(userDevs) == 0 {
			delete(h.clients, userID)
		}
	}
}

// BroadcastToUser sends an event to all authorized active devices of a user.
func (h *Hub) BroadcastToUser(userID string, event *WSEvent, excludeDeviceID string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()

	data, err := json.Marshal(event)
	if err != nil {
		return 0
	}

	count := 0
	if userDevs, exists := h.clients[userID]; exists {
		for devID, c := range userDevs {
			if devID == excludeDeviceID {
				continue
			}
			if c.Send(data) {
				count++
			}
		}
	}
	return count
}

// BroadcastToDevice sends an event to a specific device of a user.
func (h *Hub) BroadcastToDevice(userID, deviceID string, event *WSEvent) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()

	data, err := json.Marshal(event)
	if err != nil {
		return false
	}

	if userDevs, exists := h.clients[userID]; exists {
		if c, ok := userDevs[deviceID]; ok {
			return c.Send(data)
		}
	}
	return false
}

// Send delivers data to the client channel safely.
func (c *ClientConnection) Send(data []byte) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return false
	}
	select {
	case c.sendChan <- data:
		return true
	default:
		// Buffer full, drop or disconnect slow client
		return false
	}
}

// Close closes the underlying connection.
func (c *ClientConnection) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.closed {
		c.closed = true
		close(c.sendChan)
		_ = c.conn.Close()
	}
}

// UpgradeToWebSocket performs RFC 6455 handshake using Go standard library.
func UpgradeToWebSocket(w http.ResponseWriter, r *http.Request) (net.Conn, *bufio.ReadWriter, error) {
	if r.Header.Get("Upgrade") != "websocket" {
		return nil, nil, errors.New("expected websocket upgrade header")
	}

	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		return nil, nil, errors.New("missing Sec-WebSocket-Key header")
	}

	h := sha1.New()
	h.Write([]byte(key + websocketGUID))
	acceptKey := base64.StdEncoding.EncodeToString(h.Sum(nil))

	hijacker, ok := w.(http.Hijacker)
	if !ok {
		return nil, nil, errors.New("response writer does not support hijacking")
	}

	conn, bufrw, err := hijacker.Hijack()
	if err != nil {
		return nil, nil, err
	}

	res := fmt.Sprintf("HTTP/1.1 101 Switching Protocols\r\n"+
		"Upgrade: websocket\r\n"+
		"Connection: Upgrade\r\n"+
		"Sec-WebSocket-Accept: %s\r\n\r\n", acceptKey)

	if _, err := bufrw.WriteString(res); err != nil {
		_ = conn.Close()
		return nil, nil, err
	}
	if err := bufrw.Flush(); err != nil {
		_ = conn.Close()
		return nil, nil, err
	}

	return conn, bufrw, nil
}

// WriteWebSocketTextFrame sends a standard unfragmented text frame (opcode 0x1).
func WriteWebSocketTextFrame(w io.Writer, payload []byte) error {
	length := len(payload)
	var header []byte

	if length <= 125 {
		header = []byte{0x81, byte(length)}
	} else if length <= 65535 {
		header = make([]byte, 4)
		header[0] = 0x81
		header[1] = 126
		binary.BigEndian.PutUint16(header[2:4], uint16(length))
	} else {
		header = make([]byte, 10)
		header[0] = 0x81
		header[1] = 127
		binary.BigEndian.PutUint64(header[2:10], uint64(length))
	}

	if _, err := w.Write(header); err != nil {
		return err
	}
	_, err := w.Write(payload)
	return err
}

// ReadWebSocketFrame reads a single incoming WebSocket frame from client.
func ReadWebSocketFrame(r *bufio.Reader) (byte, []byte, error) {
	b0, err := r.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	opcode := b0 & 0x0F

	b1, err := r.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	isMasked := (b1 & 0x80) != 0
	payloadLen := int(b1 & 0x7F)

	if payloadLen == 126 {
		lenBytes := make([]byte, 2)
		if _, err := io.ReadFull(r, lenBytes); err != nil {
			return 0, nil, err
		}
		payloadLen = int(binary.BigEndian.Uint16(lenBytes))
	} else if payloadLen == 127 {
		lenBytes := make([]byte, 8)
		if _, err := io.ReadFull(r, lenBytes); err != nil {
			return 0, nil, err
		}
		payloadLen = int(binary.BigEndian.Uint64(lenBytes))
	}

	var mask [4]byte
	if isMasked {
		if _, err := io.ReadFull(r, mask[:]); err != nil {
			return 0, nil, err
		}
	}

	payload := make([]byte, payloadLen)
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}

	if isMasked {
		for i := 0; i < payloadLen; i++ {
			payload[i] ^= mask[i%4]
		}
	}

	return opcode, payload, nil
}

// HandleWebSocketConnection handles the read and write loops for an authenticated client.
func (h *Hub) HandleWebSocketConnection(userID, deviceID string, conn net.Conn, bufrw *bufio.ReadWriter) {
	client := &ClientConnection{
		UserID:   userID,
		DeviceID: deviceID,
		conn:     conn,
		bufrw:    bufrw,
		sendChan: make(chan []byte, 128),
	}

	h.Register(client)
	defer h.Unregister(userID, deviceID)

	// Writer goroutine
	go func() {
		for msg := range client.sendChan {
			if err := WriteWebSocketTextFrame(bufrw, msg); err != nil {
				break
			}
			if err := bufrw.Flush(); err != nil {
				break
			}
		}
	}()

	// Reader loop (processes incoming receipts, pings, etc.)
	for {
		opcode, payload, err := ReadWebSocketFrame(bufrw.Reader)
		if err != nil {
			break
		}
		if opcode == 0x8 { // Connection Close
			break
		}
		if opcode == 0x9 { // Ping -> send Pong
			_ = WriteWebSocketTextFrame(bufrw, []byte("pong"))
			_ = bufrw.Flush()
		}
		if opcode == 0x1 { // Text JSON message from client
			log.Printf("[WebSocket] Received frame from user %s, dev %s (%d bytes)", userID, deviceID, len(payload))
		}
	}
}
