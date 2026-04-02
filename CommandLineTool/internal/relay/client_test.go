package relay

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"cookey/internal/models"
)

func TestCanonicalBaseURLRejectsCustomPath(t *testing.T) {
	_, err := CanonicalBaseURL("https://api.cookey.sh/custom")
	if err == nil {
		t.Fatal("expected custom path to be rejected")
	}
}

func TestRegisterRetriesPairKeyCollision(t *testing.T) {
	attempts := 0
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts < 3 {
			w.WriteHeader(http.StatusConflict)
			w.Write([]byte(`{"error":"Pair key collision"}`))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		w.Write([]byte(`{"pair_key":"SM8ND67N"}`))
	}))
	defer server.Close()

	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatalf("parse server URL: %v", err)
	}
	client := &Client{
		baseURL:    baseURL,
		httpClient: server.Client(),
	}

	pairKey, err := client.Register(models.LoginManifest{
		RID:           "r_test",
		TargetURL:     "https://example.com",
		ServerURL:     server.URL,
		CLIPublicKey:  "pubkey",
		DeviceID:      "device-id",
		CreatedAt:     models.NewISO8601Time(time.Now()),
		ExpiresAt:     models.NewISO8601Time(time.Now().Add(5 * time.Minute)),
		RequestSecret: "secret",
		RequestProof:  "proof",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}
	if pairKey != "SM8ND67N" {
		t.Fatalf("pairKey = %q", pairKey)
	}
	if attempts != 3 {
		t.Fatalf("attempts = %d, want 3", attempts)
	}
}
