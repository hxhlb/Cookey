package crypto

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"cookey/internal/models"
)

var (
	ErrInvalidFingerprintKey = errors.New("invalid X25519 public key for fingerprint")
)

// emojiTable maps each byte (0–255) to a single-codepoint emoji.
// This table MUST be identical across Go and Swift implementations.
// Issue: #18 — CLI Public Key Verification.
// Constraints: no ZWJ sequences, no flags, no skin-tone modifiers, no variation selectors.
var emojiTable = [256]string{
	// 0x00–0x0F
	"🍎", "🍊", "🍋", "🍇", "🍉", "🍓", "🫐", "🍒",
	"🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑",
	// 0x10–0x1F
	"🥦", "🥬", "🥒", "🌶", "🫑", "🌽", "🥕", "🫒",
	"🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🧀",
	// 0x20–0x2F
	"🥚", "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖",
	"🌭", "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆",
	// 0x30–0x3F
	"🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫", "🍝",
	"🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
	// 0x40–0x4F
	"🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡",
	"🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮",
	// 0x50–0x5F
	"🍭", "🍬", "🍫", "🍩", "🍪", "🌰", "🥜", "🫘",
	"🍯", "🥛", "🍼", "🫖", "🍵", "🧃", "🥤", "🧋",
	// 0x60–0x6F
	"🍺", "🍻", "🥂", "🍷", "🫗", "🍸", "🍹", "🧉",
	"🍾", "🧊", "🥄", "🍴", "🥣", "🥡", "🥢", "🧂",
	// 0x70–0x7F
	"⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉",
	"🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🥍", "🏏",
	// 0x80–0x8F
	"🪃", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊",
	"🥋", "🎽", "🛹", "🛼", "🛷", "⛸", "🥌", "🎿",
	// 0x90–0x9F
	"🎯", "🪀", "🎲", "🧩", "🎰", "🎳", "🎮", "🕹",
	"🎻", "🎸", "🎺", "🎷", "🪗", "🥁", "🪘", "🎹",
	// 0xA0–0xAF
	"🔔", "🎵", "🎶", "🎤", "🎧", "📻", "🎙", "📯",
	"🔕", "🔊", "🔉", "🔈", "📢", "📣", "🔇", "🪈",
	// 0xB0–0xBF
	"🌍", "🌎", "🌏", "🌐", "🧭", "🏔", "⛰", "🌋",
	"🗻", "🏕", "🏖", "🏜", "🏝", "🏞", "🏟", "🏛",
	// 0xC0–0xCF
	"🏗", "🧱", "🪨", "🪵", "🛖", "🏘", "🏚", "🏠",
	"🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩",
	// 0xD0–0xDF
	"🏪", "🏫", "🏬", "🏭", "🏯", "🏰", "💒", "🗼",
	"🗽", "⛪", "🕌", "🛕", "🕍", "⛩", "🕋", "⛲",
	// 0xE0–0xEF
	"🌁", "🌃", "🏙", "🌄", "🌅", "🌆", "🌇", "🌉",
	"🎠", "🛝", "🎡", "🎢", "💈", "🎪", "🚂", "🚃",
	// 0xF0–0xFF
	"🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚝",
	"🚞", "🚋", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒",
}

// emojiTableChecksum returns the SHA-256 hex digest of all 256 emoji entries
// concatenated with newline separators. Used for cross-platform drift detection.
func emojiTableChecksum() string {
	h := sha256.New()
	for i, e := range emojiTable {
		if i > 0 {
			h.Write([]byte("\n"))
		}
		h.Write([]byte(e))
	}
	return fmt.Sprintf("%x", h.Sum(nil))
}

// Fingerprint computes a human-readable fingerprint from a base64-encoded
// X25519 public key. Format: "a3f7:b2e9:8c4d  🍎 🔑 🌟 💻 🔒 ✨"
// The hex portion is canonical; emoji is a visual aid.
func Fingerprint(x25519PublicKeyBase64 string) (string, error) {
	keyBytes, err := base64.StdEncoding.DecodeString(x25519PublicKeyBase64)
	if err != nil {
		return "", ErrInvalidFingerprintKey
	}
	if len(keyBytes) != 32 {
		return "", ErrInvalidFingerprintKey
	}
	return fingerprintFromBytes(keyBytes), nil
}

// FingerprintFromKeypair derives the X25519 public key from a stored Ed25519
// keypair and computes its fingerprint.
func FingerprintFromKeypair(keypair models.KeypairFile) (string, error) {
	pubKeyBase64, err := X25519PublicKeyBase64(keypair)
	if err != nil {
		return "", err
	}
	return Fingerprint(pubKeyBase64)
}

func fingerprintFromBytes(key []byte) string {
	digest := sha256.Sum256(key)

	// Hex: bytes 0–5 → three colon-separated 2-byte groups
	hex := fmt.Sprintf("%02x%02x:%02x%02x:%02x%02x",
		digest[0], digest[1], digest[2], digest[3], digest[4], digest[5])

	// Emoji: bytes 6–11 → 6 emoji from lookup table
	emojis := make([]string, 6)
	for i := 0; i < 6; i++ {
		emojis[i] = emojiTable[digest[6+i]]
	}

	return hex + "  " + strings.Join(emojis, " ")
}
