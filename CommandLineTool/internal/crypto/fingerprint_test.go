package crypto

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

type fingerprintFixture struct {
	X25519PublicKeyBase64 string `json:"x25519_public_key_base64"`
	ExpectedFingerprint   string `json:"expected_fingerprint"`
	ExpectedHex           string `json:"expected_hex"`
	ExpectedEmoji         string `json:"expected_emoji"`
	EmojiTableChecksum    string `json:"emoji_table_checksum"`
}

func loadFingerprintFixture(t *testing.T) fingerprintFixture {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", "fingerprint_fixture.json"))
	if err != nil {
		t.Fatalf("failed to read fixture: %v", err)
	}
	var f fingerprintFixture
	if err := json.Unmarshal(data, &f); err != nil {
		t.Fatalf("failed to unmarshal fixture: %v", err)
	}
	return f
}

func TestFingerprintGoldenFixture(t *testing.T) {
	f := loadFingerprintFixture(t)

	got, err := Fingerprint(f.X25519PublicKeyBase64)
	if err != nil {
		t.Fatalf("Fingerprint() error = %v", err)
	}

	if got != f.ExpectedFingerprint {
		t.Fatalf("Fingerprint() = %q, want %q", got, f.ExpectedFingerprint)
	}

	// Also verify the hex and emoji portions independently.
	parts := strings.SplitN(got, "  ", 2)
	if len(parts) != 2 {
		t.Fatalf("expected two parts separated by double space, got %d", len(parts))
	}
	if parts[0] != f.ExpectedHex {
		t.Fatalf("hex portion = %q, want %q", parts[0], f.ExpectedHex)
	}
	if parts[1] != f.ExpectedEmoji {
		t.Fatalf("emoji portion = %q, want %q", parts[1], f.ExpectedEmoji)
	}
}

func TestFingerprintInvalidInput(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{"empty string", ""},
		{"invalid base64", "not-valid-base64!!!"},
		{"wrong length (16 bytes)", "AAECAwQFBgcICQoLDA0ODw=="},
		{"wrong length (48 bytes)", "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4v"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Fingerprint(tt.input)
			if err == nil {
				t.Fatal("Fingerprint() expected error, got nil")
			}
			if err != ErrInvalidFingerprintKey {
				t.Fatalf("Fingerprint() error = %v, want %v", err, ErrInvalidFingerprintKey)
			}
		})
	}
}

func TestFingerprintDeterministic(t *testing.T) {
	f := loadFingerprintFixture(t)

	results := make([]string, 100)
	for i := range results {
		fp, err := Fingerprint(f.X25519PublicKeyBase64)
		if err != nil {
			t.Fatalf("iteration %d: Fingerprint() error = %v", i, err)
		}
		results[i] = fp
	}

	for i := 1; i < len(results); i++ {
		if results[i] != results[0] {
			t.Fatalf("iteration %d produced %q, want %q", i, results[i], results[0])
		}
	}
}

func TestEmojiTableChecksum(t *testing.T) {
	f := loadFingerprintFixture(t)

	got := emojiTableChecksum()
	if got != f.EmojiTableChecksum {
		t.Fatalf("emojiTableChecksum() = %q, want %q", got, f.EmojiTableChecksum)
	}
}

func TestFingerprintFormat(t *testing.T) {
	f := loadFingerprintFixture(t)

	fp, err := Fingerprint(f.X25519PublicKeyBase64)
	if err != nil {
		t.Fatalf("Fingerprint() error = %v", err)
	}

	// Overall format: hex:hex:hex  emoji emoji emoji emoji emoji emoji
	// Hex portion: three groups of 4 hex chars separated by colons.
	// Separator: two spaces.
	// Emoji portion: six emoji separated by single spaces.
	pattern := `^[0-9a-f]{4}:[0-9a-f]{4}:[0-9a-f]{4}  .+$`
	if !regexp.MustCompile(pattern).MatchString(fp) {
		t.Fatalf("fingerprint %q does not match expected pattern %s", fp, pattern)
	}

	parts := strings.SplitN(fp, "  ", 2)
	if len(parts) != 2 {
		t.Fatalf("expected two parts separated by double space, got %d", len(parts))
	}

	hexPart := parts[0]
	hexGroups := strings.Split(hexPart, ":")
	if len(hexGroups) != 3 {
		t.Fatalf("hex portion has %d colon-separated groups, want 3", len(hexGroups))
	}
	for i, g := range hexGroups {
		if len(g) != 4 {
			t.Fatalf("hex group %d = %q, want 4 characters", i, g)
		}
	}

	emojiPart := parts[1]
	emojiTokens := strings.Split(emojiPart, " ")
	if len(emojiTokens) != 6 {
		t.Fatalf("emoji portion has %d tokens, want 6", len(emojiTokens))
	}
	for i, tok := range emojiTokens {
		if len(tok) == 0 {
			t.Fatalf("emoji token %d is empty", i)
		}
	}
}
