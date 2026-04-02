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
