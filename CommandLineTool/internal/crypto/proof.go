package crypto

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"cookey/internal/models"
)

var (
	ErrInvalidRequestSecret = errors.New("invalid request secret")
	ErrInvalidRequestProof  = errors.New("request proof verification failed")
	ErrInvalidSessionProof  = errors.New("session proof verification failed")
)

func GenerateRequestSecret() (string, error) {
	bytes, err := RandomBytes(32)
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func ComputeRequestProof(manifest models.LoginManifest, requestSecret string) (string, error) {
	secretBytes, err := decodeRequestSecret(requestSecret)
	if err != nil {
		return "", err
	}
	message := strings.Join([]string{
		"cookey-request-v1",
		manifest.RID,
		manifest.ServerURL,
		manifest.TargetURL,
		manifest.CLIPublicKey,
		manifest.DeviceID,
		manifest.RequestType,
		formatProofTime(manifest.ExpiresAt.Time),
	}, "\n")
	return computeProof(secretBytes, message), nil
}

func VerifyRequestProof(manifest models.LoginManifest, requestSecret, expected string) error {
	actual, err := ComputeRequestProof(manifest, requestSecret)
	if err != nil {
		return err
	}
	if !hmac.Equal([]byte(actual), []byte(expected)) {
		return ErrInvalidRequestProof
	}
	return nil
}

func ComputeEnvelopeProof(rid string, envelope models.EncryptedSessionEnvelope, requestSecret string) (string, error) {
	secretBytes, err := decodeRequestSecret(requestSecret)
	if err != nil {
		return "", err
	}
	message := strings.Join([]string{
		"cookey-session-v1",
		rid,
		string(envelope.Algorithm),
		envelope.EphemeralPublicKey,
		envelope.Nonce,
		envelope.Ciphertext,
		formatProofTime(envelope.CapturedAt.Time),
		strconv.Itoa(envelope.Version),
	}, "\n")
	return computeProof(secretBytes, message), nil
}

func VerifyEnvelopeProof(rid string, envelope models.EncryptedSessionEnvelope, requestSecret string) error {
	actual, err := ComputeEnvelopeProof(rid, envelope, requestSecret)
	if err != nil {
		return err
	}
	if !hmac.Equal([]byte(actual), []byte(envelope.RequestSignature)) {
		return ErrInvalidSessionProof
	}
	return nil
}

func decodeRequestSecret(requestSecret string) ([]byte, error) {
	secretBytes, err := base64.RawURLEncoding.DecodeString(strings.TrimSpace(requestSecret))
	if err != nil || len(secretBytes) < 16 {
		return nil, ErrInvalidRequestSecret
	}
	return secretBytes, nil
}

func computeProof(secret []byte, message string) string {
	mac := hmac.New(sha256.New, secret)
	_, _ = mac.Write([]byte(message))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func formatProofTime(value time.Time) string {
	return value.UTC().Format(time.RFC3339)
}

func VerifiedSeedRequest(seed models.SeedRequestPayload) (models.LoginManifest, error) {
	manifest := models.LoginManifest{
		RID:           seed.RID,
		ServerURL:     seed.ServerURL,
		TargetURL:     seed.TargetURL,
		CLIPublicKey:  seed.CLIPublicKey,
		DeviceID:      seed.DeviceID,
		ExpiresAt:     seed.ExpiresAt,
		RequestType:   seed.RequestType,
		RequestProof:  seed.RequestProof,
		RequestSecret: seed.RequestSecret,
	}
	if err := VerifyRequestProof(manifest, seed.RequestSecret, seed.RequestProof); err != nil {
		return models.LoginManifest{}, fmt.Errorf("invalid seed request payload: %w", err)
	}
	return manifest, nil
}
