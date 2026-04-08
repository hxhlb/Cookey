package models

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestOriginStateMarshalJSONNormalizesNilLocalStorage(t *testing.T) {
	origin := OriginState{
		Origin:       "https://example.com",
		LocalStorage: nil,
	}

	data, err := json.Marshal(origin)
	if err != nil {
		t.Fatalf("json.Marshal() error = %v", err)
	}

	rendered := string(data)
	if !strings.Contains(rendered, `"localStorage":[]`) {
		t.Fatalf("marshaled JSON = %s, want localStorage to be []", rendered)
	}
}

func TestOriginStateUnmarshalJSONNormalizesNullLocalStorage(t *testing.T) {
	var origin OriginState
	if err := json.Unmarshal([]byte(`{"origin":"https://example.com","localStorage":null}`), &origin); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	if origin.LocalStorage == nil {
		t.Fatal("origin.LocalStorage = nil, want empty slice")
	}
	if len(origin.LocalStorage) != 0 {
		t.Fatalf("len(origin.LocalStorage) = %d, want 0", len(origin.LocalStorage))
	}
}

func TestBrowserCookieUnmarshalJSONCanonicalizesSameSite(t *testing.T) {
	var cookie BrowserCookie
	if err := json.Unmarshal([]byte(`{
		"name":"session",
		"value":"abc123",
		"domain":"example.com",
		"path":"/",
		"expires":-1,
		"httpOnly":true,
		"secure":true,
		"sameSite":"strict"
	}`), &cookie); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	if cookie.SameSite != "Strict" {
		t.Fatalf("cookie.SameSite = %q, want %q", cookie.SameSite, "Strict")
	}
}

func TestPlaywrightStorageStateMarshalJSONCanonicalizesSameSite(t *testing.T) {
	storageState := PlaywrightStorageState{
		Cookies: []BrowserCookie{{
			Name:     "session",
			Value:    "abc123",
			Domain:   "example.com",
			Path:     "/",
			Expires:  -1,
			HTTPOnly: true,
			Secure:   true,
			SameSite: "lax",
		}},
		Origins: []OriginState{{
			Origin:       "https://example.com",
			LocalStorage: []OriginStorageItem{},
		}},
	}

	data, err := json.Marshal(storageState)
	if err != nil {
		t.Fatalf("json.Marshal() error = %v", err)
	}

	rendered := string(data)
	if !strings.Contains(rendered, `"sameSite":"Lax"`) {
		t.Fatalf("marshaled JSON = %s, want sameSite to be canonicalized to Lax", rendered)
	}
}
