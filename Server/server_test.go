package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type pushCall struct {
	environment string
	requestType string
	token       string
}

type stubNotificationSender struct {
	mu    sync.Mutex
	calls []pushCall
	ch    chan pushCall
}

func newStubNotificationSender() *stubNotificationSender {
	return &stubNotificationSender{
		ch: make(chan pushCall, 32),
	}
}

func (s *stubNotificationSender) SendNotificationWithToken(request *StoredRequest, serverURL string, token string, environment string, blocker *APNTokenBlocker, sourceIP string) {
	call := pushCall{
		environment: environment,
		requestType: request.RequestType,
		token:       token,
	}
	s.mu.Lock()
	s.calls = append(s.calls, call)
	s.mu.Unlock()
	s.ch <- call
}

func (s *stubNotificationSender) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.calls)
}

func newTestServer() (*http.ServeMux, *Storage, *stubNotificationSender) {
	storage := NewStorage(1024 * 1024)
	sender := newStubNotificationSender()
	routes := &Routes{
		storage:     storage,
		config:      ServerConfig{MaxPayloadSize: 1024 * 1024, PublicURL: "https://relay.test"},
		apnsClient:  sender,
		apnBlocker:  NewAPNTokenBlocker(),
		pushLimiter: NewAPNPushRateLimiter(),
	}
	mux := http.NewServeMux()
	routes.Register(mux)
	return mux, storage, sender
}

func performJSONRequest(t *testing.T, mux *http.ServeMux, method string, path string, body any) *httptest.ResponseRecorder {
	t.Helper()

	var payload []byte
	var err error
	if body != nil {
		payload, err = json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body: %v", err)
		}
	}

	req := httptest.NewRequest(method, path, bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func mustDecodeJSON[T any](t *testing.T, rec *httptest.ResponseRecorder) T {
	t.Helper()
	var value T
	if err := json.Unmarshal(rec.Body.Bytes(), &value); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return value
}

func waitForPush(t *testing.T, sender *stubNotificationSender) pushCall {
	t.Helper()
	select {
	case call := <-sender.ch:
		return call
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for push")
		return pushCall{}
	}
}

func newLoginRequest(rid string) LoginRequest {
	return LoginRequest{
		CLIPublicKey:      "cli-public-key",
		DeviceFingerprint: "device-fingerprint",
		DeviceID:          "device-1",
		ExpiresAt:         ISO8601Time{Time: time.Now().Add(5 * time.Minute).UTC()},
		RequestProof:      "proof-1",
		RID:               rid,
		TargetURL:         "https://example.com/login",
	}
}

func newSeedSession() EncryptedSession {
	return EncryptedSession{
		Algorithm:          AlgorithmX25519XSalsa20Poly1305,
		CapturedAt:         nowISO8601(),
		Ciphertext:         "ciphertext",
		EphemeralPublicKey: "ephemeral",
		Nonce:              "nonce",
		Version:            1,
	}
}

func TestSeedSessionUploadRetrieveAndClear(t *testing.T) {
	mux, _, sender := newTestServer()

	create := newLoginRequest("rid-seed")
	create.APNEnvironment = "sandbox"
	create.APNToken = "token-1"
	create.RequestType = RequestTypeRefresh

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if sender.count() != 0 {
		t.Fatalf("refresh request unexpectedly triggered push on creation")
	}

	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests/rid-seed/seed-session", newSeedSession())
	if rec.Code != http.StatusCreated {
		t.Fatalf("upload seed status = %d, body = %s", rec.Code, rec.Body.String())
	}

	call := waitForPush(t, sender)
	if call.token != "token-1" || call.environment != "sandbox" || call.requestType != RequestTypeRefresh {
		t.Fatalf("unexpected push call: %+v", call)
	}

	rec = performJSONRequest(t, mux, http.MethodGet, "/v1/requests/rid-seed/seed-session", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("get seed status = %d, body = %s", rec.Code, rec.Body.String())
	}
	seed := mustDecodeJSON[EncryptedSession](t, rec)
	if seed.Algorithm != AlgorithmX25519XSalsa20Poly1305 {
		t.Fatalf("unexpected seed algorithm: %s", seed.Algorithm)
	}

	rec = performJSONRequest(t, mux, http.MethodGet, "/v1/requests/rid-seed/seed-session", nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("second get seed status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestCreateRequestStoresAPNFieldsAndRequestType(t *testing.T) {
	mux, storage, _ := newTestServer()

	create := newLoginRequest("rid-apn")
	create.APNEnvironment = "production"
	create.APNToken = "token-2"
	create.RequestType = RequestTypeRefresh

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}

	response := mustDecodeJSON[RequestStatusResponse](t, rec)
	if response.RequestType != RequestTypeRefresh {
		t.Fatalf("unexpected request type in response: %s", response.RequestType)
	}

	stored := storage.GetRequest("rid-apn")
	if stored == nil {
		t.Fatal("stored request not found")
	}
	if stored.APNToken != "token-2" || stored.APNEnvironment != "production" || stored.RequestType != RequestTypeRefresh {
		t.Fatalf("stored request missing APN fields: %+v", stored)
	}
}

func TestNilAPNSClientDoesNotPanicOnSeedUpload(t *testing.T) {
	storage := NewStorage(1024 * 1024)
	routes := &Routes{
		storage:     storage,
		config:      ServerConfig{MaxPayloadSize: 1024 * 1024, PublicURL: "https://relay.test"},
		apnsClient:  (*APNSClient)(nil),
		apnBlocker:  NewAPNTokenBlocker(),
		pushLimiter: NewAPNPushRateLimiter(),
	}
	mux := http.NewServeMux()
	routes.Register(mux)

	create := newLoginRequest("rid-nil-apns")
	create.APNEnvironment = "sandbox"
	create.APNToken = "token-nil"
	create.RequestType = RequestTypeRefresh

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests/rid-nil-apns/seed-session", newSeedSession())
	if rec.Code != http.StatusCreated {
		t.Fatalf("upload seed status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestSeedSessionPushRateLimit(t *testing.T) {
	mux, _, sender := newTestServer()

	for i := 0; i < 4; i++ {
		rid := "rid-rate-" + string(rune('a'+i))
		create := newLoginRequest(rid)
		create.APNEnvironment = "sandbox"
		create.APNToken = "shared-token"
		create.RequestType = RequestTypeRefresh

		rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
		if rec.Code != http.StatusCreated {
			t.Fatalf("create request %d status = %d, body = %s", i, rec.Code, rec.Body.String())
		}

		rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests/"+rid+"/seed-session", newSeedSession())
		if rec.Code != http.StatusCreated {
			t.Fatalf("upload seed %d status = %d, body = %s", i, rec.Code, rec.Body.String())
		}
	}

	for i := 0; i < 3; i++ {
		waitForPush(t, sender)
	}
	select {
	case call := <-sender.ch:
		t.Fatalf("unexpected fourth push: %+v", call)
	case <-time.After(200 * time.Millisecond):
	}
	if sender.count() != 3 {
		t.Fatalf("push count = %d, want 3", sender.count())
	}
}

func TestAPNTokenBlocker(t *testing.T) {
	blocker := NewAPNTokenBlocker()
	const token = "token-a"
	const ip = "203.0.113.8"

	blocker.RecordFailure(token, ip)
	blocker.RecordFailure(token, ip)
	if blocker.IsBlocked(token) {
		t.Fatal("token blocked too early")
	}

	blocker.RecordSuccess(token, ip)
	blocker.RecordFailure(token, ip)
	blocker.RecordFailure(token, ip)
	if blocker.IsBlocked(token) {
		t.Fatal("token blocked after reset too early")
	}

	const tokenB = "token-b"
	blocker.tokenIPs[tokenB] = ip

	blocker.RecordFailure(token, ip)
	if !blocker.IsBlocked(token) {
		t.Fatal("token should be blocked after third consecutive failure")
	}

	if !blocker.IsBlocked(tokenB) {
		t.Fatal("second token should be blocked via source IP association")
	}

	blocker.blocked[token] = time.Now().Add(-time.Second)
	blocker.ipBlock[ip] = time.Now().Add(-time.Second)
	blocker.Cleanup()
	if blocker.IsBlocked(token) {
		t.Fatal("token should not remain blocked after cleanup")
	}
}

func TestRequestValidation(t *testing.T) {
	mux, _, _ := newTestServer()

	invalidType := newLoginRequest("rid-invalid-type")
	invalidType.RequestType = "bogus"
	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", invalidType)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid request type status = %d, body = %s", rec.Code, rec.Body.String())
	}

	invalidToken := newLoginRequest("rid-invalid-token")
	invalidToken.APNToken = "token-only"
	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests", invalidToken)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("partial APN fields status = %d, body = %s", rec.Code, rec.Body.String())
	}

	invalidEnvironment := newLoginRequest("rid-invalid-env")
	invalidEnvironment.APNToken = "token"
	invalidEnvironment.APNEnvironment = "staging"
	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests", invalidEnvironment)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid environment status = %d, body = %s", rec.Code, rec.Body.String())
	}

	missingProof := newLoginRequest("rid-missing-proof")
	missingProof.RequestProof = ""
	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests", missingProof)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("missing proof status = %d, body = %s", rec.Code, rec.Body.String())
	}

	validRefresh := newLoginRequest("rid-seed-validation")
	validRefresh.APNToken = "token"
	validRefresh.APNEnvironment = "sandbox"
	validRefresh.RequestType = RequestTypeRefresh
	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests", validRefresh)
	if rec.Code != http.StatusCreated {
		t.Fatalf("valid refresh status = %d, body = %s", rec.Code, rec.Body.String())
	}

	invalidSeed := newSeedSession()
	invalidSeed.Algorithm = "bogus"
	rec = performJSONRequest(t, mux, http.MethodPost, "/v1/requests/rid-seed-validation/seed-session", invalidSeed)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid seed algorithm status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestResolvePairKeyIncludesRequestProof(t *testing.T) {
	mux, _, _ := newTestServer()

	create := newLoginRequest("rid-pair")
	create.RequestProof = "request-proof"

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}

	response := mustDecodeJSON[RequestStatusResponse](t, rec)
	if response.PairKey == "" {
		t.Fatal("expected pair key in create response")
	}

	rec = performJSONRequest(t, mux, http.MethodGet, "/v1/pair/"+response.PairKey, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("pair resolve status = %d, body = %s", rec.Code, rec.Body.String())
	}

	pair := mustDecodeJSON[PairKeyResponse](t, rec)
	if pair.RequestProof != "request-proof" {
		t.Fatalf("request proof mismatch: %q", pair.RequestProof)
	}
}

func TestCreateRequestReturnsConflictOnPairKeyCollision(t *testing.T) {
	storage := NewStorage(1024 * 1024)
	storage.pairKeys["SM8ND67N"] = "rid-existing"
	storage.pairKeyGenerator = func() string { return "SM8ND67N" }

	routes := &Routes{
		storage:     storage,
		config:      ServerConfig{MaxPayloadSize: 1024 * 1024, PublicURL: "https://relay.test"},
		apnsClient:  newStubNotificationSender(),
		apnBlocker:  NewAPNTokenBlocker(),
		pushLimiter: NewAPNPushRateLimiter(),
	}
	mux := http.NewServeMux()
	routes.Register(mux)

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", newLoginRequest("rid-collision"))
	if rec.Code != http.StatusConflict {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func createAndGetPairKey(t *testing.T, mux *http.ServeMux, rid string) string {
	t.Helper()
	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", newLoginRequest(rid))
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, body = %s", rec.Code, rec.Body.String())
	}
	resp := mustDecodeJSON[RequestStatusResponse](t, rec)
	if resp.PairKey == "" {
		t.Fatal("expected pair key in create response")
	}
	return resp.PairKey
}

func TestJumpRedirectsToDeepLink(t *testing.T) {
	mux, _, _ := newTestServer()
	pairKey := createAndGetPairKey(t, mux, "rid-jump")

	code := pairKey[:4] + "-" + pairKey[4:]
	req := httptest.NewRequest(http.MethodGet, "/jump?code="+code, nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusFound {
		t.Fatalf("jump status = %d, body = %s", rec.Code, rec.Body.String())
	}
	location := rec.Header().Get("Location")
	// Test server PublicURL is "https://relay.test" which is not api.cookey.sh,
	// so the redirect should include ?host=relay.test
	expected := "cookey://" + pairKey + "?host=relay.test"
	if location != expected {
		t.Fatalf("location = %q, want %q", location, expected)
	}
}

func TestJumpDefaultServerOmitsHost(t *testing.T) {
	storage := NewStorage(1024 * 1024)
	routes := &Routes{
		storage:     storage,
		config:      ServerConfig{MaxPayloadSize: 1024 * 1024, PublicURL: "https://api.cookey.sh"},
		apnsClient:  newStubNotificationSender(),
		apnBlocker:  NewAPNTokenBlocker(),
		pushLimiter: NewAPNPushRateLimiter(),
	}
	mux := http.NewServeMux()
	routes.Register(mux)

	pairKey := createAndGetPairKey(t, mux, "rid-jump-default")
	code := pairKey[:4] + "-" + pairKey[4:]
	req := httptest.NewRequest(http.MethodGet, "/jump?code="+code, nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusFound {
		t.Fatalf("jump status = %d, body = %s", rec.Code, rec.Body.String())
	}
	expected := "cookey://" + pairKey
	if location := rec.Header().Get("Location"); location != expected {
		t.Fatalf("location = %q, want %q", location, expected)
	}
}

func TestJumpMissingCode(t *testing.T) {
	mux, _, _ := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/jump", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("jump missing code status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestJumpInvalidCode(t *testing.T) {
	mux, _, _ := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/jump?code=ZZZZ-ZZZZ", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("jump invalid code status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestJumpExpiredRequest(t *testing.T) {
	mux, storage, _ := newTestServer()

	create := newLoginRequest("rid-jump-expired")
	create.ExpiresAt = ISO8601Time{Time: time.Now().Add(1 * time.Second).UTC()}
	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/requests", create)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create status = %d", rec.Code)
	}
	resp := mustDecodeJSON[RequestStatusResponse](t, rec)
	pairKey := resp.PairKey

	// Force expiry by directly mutating the stored request
	storage.mu.Lock()
	storage.requests["rid-jump-expired"].ExpiresAt = time.Now().Add(-1 * time.Second)
	storage.mu.Unlock()

	code := pairKey[:4] + "-" + pairKey[4:]
	req := httptest.NewRequest(http.MethodGet, "/jump?code="+code, nil)
	rec2 := httptest.NewRecorder()
	mux.ServeHTTP(rec2, req)

	if rec2.Code != http.StatusGone {
		t.Fatalf("jump expired status = %d, body = %s", rec2.Code, rec2.Body.String())
	}
}

func TestJumpStripsMultipleDashes(t *testing.T) {
	mux, _, _ := newTestServer()
	pairKey := createAndGetPairKey(t, mux, "rid-jump-dashes")

	// Send code with dashes in unusual positions
	code := string(pairKey[0]) + "-" + string(pairKey[1]) + "-" + pairKey[2:]
	req := httptest.NewRequest(http.MethodGet, "/jump?code="+code, nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusFound {
		t.Fatalf("jump multi-dash status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestDeviceRegistrationEndpointRemoved(t *testing.T) {
	mux, _, _ := newTestServer()

	rec := performJSONRequest(t, mux, http.MethodPost, "/v1/devices/device-1/apn-token", map[string]string{"token": "token", "environment": "sandbox"})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("device registration POST status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = performJSONRequest(t, mux, http.MethodDelete, "/v1/devices/device-1/apn-token", nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("device registration DELETE status = %d, body = %s", rec.Code, rec.Body.String())
	}
}
