package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func call(s *Server, method, path, body string, hdr map[string]string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, bytes.NewBufferString(body))
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	return rec
}

func TestAccountDeletionFlow(t *testing.T) {
	s := setupTestServer()
	rec := call(s, "POST", "/api/v1/auth/register", `{"handle":"@dina","display_name":"Dina","recovery_code":"MRX-DINA-1"}`, nil)
	if rec.Code != http.StatusCreated {
		t.Fatalf("register: %d %s", rec.Code, rec.Body.String())
	}
	var reg struct {
		User struct {
			ID           string `json:"id"`
			RecoveryCode string `json:"recovery_code"`
		} `json:"user"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &reg)
	if reg.User.RecoveryCode != "MRX-DINA-1" {
		t.Fatal("owner must receive their recovery code on register")
	}
	if r := call(s, "POST", "/api/v1/auth/recover", `{"recovery_code":"WRONG-CODE","preferred_handle":"@dina"}`, nil); r.Code != http.StatusNotFound {
		t.Fatalf("handle alone must not recover an account, got %d", r.Code)
	}

	// Public listing must never leak recovery codes
	list := call(s, "GET", "/api/v1/users", "", nil)
	if strings.Contains(list.Body.String(), "MRX-DINA-1") || strings.Contains(list.Body.String(), "recovery_code") {
		t.Fatalf("recovery code leaked in listing: %s", list.Body.String())
	}

	// Deletion requires ownership proof
	if r := call(s, "DELETE", "/api/v1/users/"+reg.User.ID, "", nil); r.Code != http.StatusForbidden {
		t.Fatalf("delete without proof must be 403, got %d", r.Code)
	}
	if r := call(s, "DELETE", "/api/v1/users/"+reg.User.ID, "", map[string]string{"X-MRixk-Recovery-Code": "WRONG"}); r.Code != http.StatusForbidden {
		t.Fatalf("delete with wrong proof must be 403, got %d", r.Code)
	}
	if r := call(s, "DELETE", "/api/v1/users/"+reg.User.ID, "", map[string]string{"X-MRixk-Recovery-Code": "MRX-DINA-1"}); r.Code != http.StatusOK {
		t.Fatalf("owner delete must succeed, got %d", r.Code)
	}

	if r := call(s, "GET", "/api/v1/users/"+reg.User.ID, "", nil); r.Code != http.StatusGone {
		t.Fatalf("deleted user must be 410, got %d", r.Code)
	}
	if r := call(s, "POST", "/api/v1/auth/restore", `{"user_id":"`+reg.User.ID+`","handle":"@dina","display_name":"Dina","recovery_code":"MRX-DINA-1"}`, nil); r.Code != http.StatusGone {
		t.Fatalf("deleted account must not be restorable, got %d", r.Code)
	}
	st := call(s, "POST", "/api/v1/users/status", `{"ids":["`+reg.User.ID+`"]}`, nil)
	if !strings.Contains(st.Body.String(), `"deleted":[{`) {
		t.Fatalf("status must report deletion: %s", st.Body.String())
	}
	if r := call(s, "POST", "/api/v1/auth/register", `{"handle":"@dina","display_name":"X"}`, nil); r.Code != http.StatusConflict {
		t.Fatalf("handle must be reserved 24h, got %d", r.Code)
	}
	if r := call(s, "POST", "/api/v1/auth/recover", `{"recovery_code":"MRX-DINA-1"}`, nil); r.Code == http.StatusOK {
		t.Fatal("deleted account must not be recoverable")
	}
}

func TestRestoreAfterServerResetPreservesIdentity(t *testing.T) {
	s := setupTestServer()
	rec := call(s, "POST", "/api/v1/auth/restore", `{"user_id":"usr-stable-1","handle":"@restoreme","display_name":"Restore Me","recovery_code":"MRX-RESTORE-1"}`, nil)
	if rec.Code != http.StatusCreated {
		t.Fatalf("restore after reset: %d %s", rec.Code, rec.Body.String())
	}
	var body struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.User.ID != "usr-stable-1" {
		t.Fatalf("restored user ID changed: %q", body.User.ID)
	}
}
