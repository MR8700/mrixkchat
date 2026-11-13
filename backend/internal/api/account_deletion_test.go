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

func TestFirstContactMessageRequestCanBeReceivedAndAccepted(t *testing.T) {
	s := setupTestServer()
	register := func(handle, code string) string {
		rec := call(s, "POST", "/api/v1/auth/register", `{"handle":"`+handle+`","display_name":"`+handle+`","recovery_code":"`+code+`"}`, nil)
		if rec.Code != http.StatusCreated {
			t.Fatalf("register %s: %d %s", handle, rec.Code, rec.Body.String())
		}
		var result struct {
			User struct {
				ID string `json:"id"`
			} `json:"user"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		return result.User.ID
	}
	senderID := register("@sender", "MRX-SENDER-1")
	recipientID := register("@recipient", "MRX-RECIPIENT-1")
	postPath := "/api/v1/users/" + senderID + "/message-requests"
	postBody := `{"id":"msg-1","recipient_id":"` + recipientID + `","conversation_id":"conv-1","content":"Bonjour","message_type":"text"}`
	if r := call(s, "POST", postPath, postBody, map[string]string{"X-MRixk-Recovery-Code": "MRX-SENDER-1"}); r.Code != http.StatusCreated {
		t.Fatalf("send request: %d %s", r.Code, r.Body.String())
	}
	inboxPath := "/api/v1/users/" + recipientID + "/message-requests"
	if r := call(s, "GET", inboxPath, "", nil); r.Code != http.StatusForbidden {
		t.Fatalf("inbox without owner proof must be forbidden, got %d", r.Code)
	}
	inbox := call(s, "GET", inboxPath, "", map[string]string{"X-MRixk-Recovery-Code": "MRX-RECIPIENT-1"})
	if inbox.Code != http.StatusOK || !strings.Contains(inbox.Body.String(), `"content":"Bonjour"`) || !strings.Contains(inbox.Body.String(), `"status":"PENDING"`) {
		t.Fatalf("recipient inbox should contain a pending request: %d %s", inbox.Code, inbox.Body.String())
	}
	var response struct {
		Requests []struct {
			ID string `json:"id"`
		} `json:"requests"`
	}
	if err := json.Unmarshal(inbox.Body.Bytes(), &response); err != nil || len(response.Requests) != 1 {
		t.Fatalf("bad inbox payload: %v", err)
	}
	acceptPath := inboxPath + "/" + response.Requests[0].ID
	if r := call(s, "POST", acceptPath, `{"status":"ACCEPTED"}`, map[string]string{"X-MRixk-Recovery-Code": "MRX-RECIPIENT-1"}); r.Code != http.StatusOK {
		t.Fatalf("accept request: %d %s", r.Code, r.Body.String())
	}
	postBody = strings.Replace(postBody, "msg-1", "msg-2", 1)
	if r := call(s, "POST", postPath, postBody, map[string]string{"X-MRixk-Recovery-Code": "MRX-SENDER-1"}); r.Code != http.StatusCreated || !strings.Contains(r.Body.String(), `"status":"ACCEPTED"`) {
		t.Fatalf("subsequent message should be delivered to accepted thread: %d %s", r.Code, r.Body.String())
	}
}
