package api

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/messaging"
)

func TestPWAStaticServing(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "mrixk_pwa_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Create dummy index.html and dummy asset
	indexContent := "<html><body>MRixk PWA Root</body></html>"
	if err := os.WriteFile(filepath.Join(tempDir, "index.html"), []byte(indexContent), 0644); err != nil {
		t.Fatalf("failed to write index.html: %v", err)
	}
	if err := os.WriteFile(filepath.Join(tempDir, "manifest.json"), []byte(`{"name":"MRixk"}`), 0644); err != nil {
		t.Fatalf("failed to write manifest.json: %v", err)
	}

	t.Setenv("STATIC_WEB_DIR", tempDir)

	repo := database.NewMemoryRepository(3)
	idService := identity.NewService(repo)
	deviceService := devices.NewService(repo)
	msgService := messaging.NewService(repo)
	server := NewServer(idService, deviceService, msgService, repo)

	// 1. Test GET / serves index.html
	req := httptest.NewRequest("GET", "/", nil)
	rr := httptest.NewRecorder()
	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK for /, got %d", rr.Code)
	}
	if rr.Body.String() != indexContent {
		t.Errorf("expected index content, got: %s", rr.Body.String())
	}
	if rr.Header().Get("Cache-Control") != "no-cache, no-store, must-revalidate" {
		t.Errorf("expected no-cache header on index.html, got %s", rr.Header().Get("Cache-Control"))
	}

	// 2. Test GET /manifest.json serves manifest with no-cache
	req = httptest.NewRequest("GET", "/manifest.json", nil)
	rr = httptest.NewRecorder()
	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK for /manifest.json, got %d", rr.Code)
	}

	// 3. Test SPA fallback on arbitrary route (e.g. /settings/security)
	req = httptest.NewRequest("GET", "/settings/security", nil)
	rr = httptest.NewRecorder()
	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK for SPA fallback route, got %d", rr.Code)
	}
	if rr.Body.String() != indexContent {
		t.Errorf("expected index content for SPA fallback, got: %s", rr.Body.String())
	}

	// 4. Test API route is not hijacked by static handler
	req = httptest.NewRequest("GET", "/api/v1/health", nil)
	rr = httptest.NewRecorder()
	server.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK for health, got %d", rr.Code)
	}
}
