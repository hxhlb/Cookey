package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha512"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/nacl/box"

	"cookey/internal/fileutil"
	"cookey/internal/models"
)

var (
	ErrInvalidAlgorithm          = errors.New("unsupported key algorithm")
	ErrInvalidPrivateKey         = errors.New("invalid Ed25519 private key")
	ErrInvalidPublicKey          = errors.New("invalid Ed25519 public key")
	ErrInvalidEphemeralPublicKey = errors.New("invalid X25519 ephemeral public key")
	ErrInvalidNonce              = errors.New("invalid XSalsa20 nonce")
	ErrInvalidCiphertext         = errors.New("invalid ciphertext payload")
	ErrDecryptionFailed          = errors.New("unable to decrypt session payload")
)

func LoadOrCreate(path string) (models.KeypairFile, error) {
	if data, err := os.ReadFile(path); err == nil {
		var keypair models.KeypairFile
		if err := json.Unmarshal(data, &keypair); err != nil {
			return models.KeypairFile{}, err
		}
		return keypair, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return models.KeypairFile{}, err
	}

	keypair, err := Generate()
	if err != nil {
		return models.KeypairFile{}, err
	}

	data, err := json.MarshalIndent(keypair, "", "  ")
	if err != nil {
		return models.KeypairFile{}, err
	}
	data = append(data, '\n')

	if err := fileutil.WriteFileAtomically(path, data, 0o600); err != nil {
		return models.KeypairFile{}, err
	}

	return keypair, nil
}

func Generate() (models.KeypairFile, error) {
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return models.KeypairFile{}, err
	}

	return models.KeypairFile{
		Version:    1,
		Algorithm:  "ed25519",
		PublicKey:  base64.StdEncoding.EncodeToString(publicKey),
		PrivateKey: base64.StdEncoding.EncodeToString(privateKey.Seed()),
		CreatedAt:  models.NewISO8601Time(time.Now()),
	}, nil
}

func Ed25519PrivateKey(keypair models.KeypairFile) (ed25519.PrivateKey, error) {
	if !strings.EqualFold(keypair.Algorithm, "ed25519") {
		return nil, fmt.Errorf("%w: %s", ErrInvalidAlgorithm, keypair.Algorithm)
	}

	seed, err := base64.StdEncoding.DecodeString(keypair.PrivateKey)
	if err != nil || len(seed) != ed25519.SeedSize {
		return nil, ErrInvalidPrivateKey
	}

	return ed25519.NewKeyFromSeed(seed), nil
}

func Ed25519PublicKey(keypair models.KeypairFile) (ed25519.PublicKey, error) {
	if !strings.EqualFold(keypair.Algorithm, "ed25519") {
		return nil, fmt.Errorf("%w: %s", ErrInvalidAlgorithm, keypair.Algorithm)
	}

	publicKey, err := base64.StdEncoding.DecodeString(keypair.PublicKey)
	if err != nil || len(publicKey) != ed25519.PublicKeySize {
		return nil, ErrInvalidPublicKey
	}

	return ed25519.PublicKey(publicKey), nil
}

func DeriveX25519PrivateKey(keypair models.KeypairFile) ([32]byte, error) {
	privateKey, err := Ed25519PrivateKey(keypair)
	if err != nil {
		return [32]byte{}, err
	}

	digest := sha512.Sum512(privateKey.Seed())
	digest[0] &= 248
	digest[31] &= 127
	digest[31] |= 64

	var scalar [32]byte
	copy(scalar[:], digest[:32])
	return scalar, nil
}

func X25519PublicKeyBase64(keypair models.KeypairFile) (string, error) {
	privateKey, err := DeriveX25519PrivateKey(keypair)
	if err != nil {
		return "", err
	}

	publicKey, err := curve25519.X25519(privateKey[:], curve25519.Basepoint)
	if err != nil {
		return "", err
	}

	return base64.StdEncoding.EncodeToString(publicKey), nil
}

func EncryptSessionEnvelope(plaintext []byte, recipientPublicKeyBase64 string) (models.EncryptedSessionEnvelope, error) {
	recipientPublicKeyBytes, err := base64.StdEncoding.DecodeString(recipientPublicKeyBase64)
	if err != nil || len(recipientPublicKeyBytes) != 32 {
		return models.EncryptedSessionEnvelope{}, ErrInvalidPublicKey
	}

	ephemeralPublicKey, ephemeralPrivateKey, err := box.GenerateKey(rand.Reader)
	if err != nil {
		return models.EncryptedSessionEnvelope{}, err
	}

	var recipientPublicKey [32]byte
	copy(recipientPublicKey[:], recipientPublicKeyBytes)

	var nonce [24]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		return models.EncryptedSessionEnvelope{}, err
	}

	ciphertext := box.Seal(nil, plaintext, &nonce, &recipientPublicKey, ephemeralPrivateKey)

	return models.EncryptedSessionEnvelope{
		Version:            1,
		Algorithm:          models.SessionEncryptionAlgorithmX25519XSalsa20Poly1305,
		EphemeralPublicKey: base64.StdEncoding.EncodeToString(ephemeralPublicKey[:]),
		Nonce:              base64.StdEncoding.EncodeToString(nonce[:]),
		Ciphertext:         base64.StdEncoding.EncodeToString(ciphertext),
		CapturedAt:         models.NewISO8601Time(time.Now()),
	}, nil
}

func DecryptSessionEnvelope(envelope models.EncryptedSessionEnvelope, keypair models.KeypairFile) ([]byte, error) {
	if !strings.EqualFold(string(envelope.Algorithm), string(models.SessionEncryptionAlgorithmX25519XSalsa20Poly1305)) {
		return nil, fmt.Errorf("%w: %s", ErrInvalidAlgorithm, envelope.Algorithm)
	}

	ephemeralKey, err := base64.StdEncoding.DecodeString(envelope.EphemeralPublicKey)
	if err != nil || len(ephemeralKey) != 32 {
		return nil, ErrInvalidEphemeralPublicKey
	}

	nonceBytes, err := base64.StdEncoding.DecodeString(envelope.Nonce)
	if err != nil || len(nonceBytes) != 24 {
		return nil, ErrInvalidNonce
	}

	ciphertext, err := base64.StdEncoding.DecodeString(envelope.Ciphertext)
	if err != nil || len(ciphertext) < 16 {
		return nil, ErrInvalidCiphertext
	}

	privateKey, err := DeriveX25519PrivateKey(keypair)
	if err != nil {
		return nil, err
	}

	var peerPublicKey [32]byte
	copy(peerPublicKey[:], ephemeralKey)

	var sharedKey [32]byte
	box.Precompute(&sharedKey, &peerPublicKey, &privateKey)

	var nonce [24]byte
	copy(nonce[:], nonceBytes)

	plaintext, ok := box.OpenAfterPrecomputation(nil, ciphertext, &nonce, &sharedKey)
	if !ok {
		return nil, ErrDecryptionFailed
	}

	return plaintext, nil
}

func GenerateRequestID() (string, error) {
	bytes, err := RandomBytes(16)
	if err != nil {
		return "", err
	}

	return "r_" + base64.RawURLEncoding.EncodeToString(bytes), nil
}

func RandomBytes(length int) ([]byte, error) {
	buf := make([]byte, length)
	if _, err := rand.Read(buf); err != nil {
		return nil, err
	}
	return buf, nil
}

