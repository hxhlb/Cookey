package crypto

import (
	"testing"
	"time"

	"cookey/internal/models"
)

func TestRequestProofRoundTrip(t *testing.T) {
	manifest := models.LoginManifest{
		RID:          "r_test",
		ServerURL:    "https://api.cookey.sh",
		TargetURL:    "https://example.com/login",
		CLIPublicKey: "pubkey",
		DeviceID:     "device-1",
		RequestType:  "login",
		ExpiresAt:    models.NewISO8601Time(time.Unix(1_775_000_000, 0)),
	}

	secret, err := GenerateRequestSecret()
	if err != nil {
		t.Fatalf("GenerateRequestSecret() error = %v", err)
	}

	proof, err := ComputeRequestProof(manifest, secret)
	if err != nil {
		t.Fatalf("ComputeRequestProof() error = %v", err)
	}

	if err := VerifyRequestProof(manifest, secret, proof); err != nil {
		t.Fatalf("VerifyRequestProof() error = %v", err)
	}

	manifest.TargetURL = "https://example.com/other"
	if err := VerifyRequestProof(manifest, secret, proof); err == nil {
		t.Fatal("VerifyRequestProof() should fail after payload mutation")
	}
}

func TestEnvelopeProofRoundTrip(t *testing.T) {
	secret, err := GenerateRequestSecret()
	if err != nil {
		t.Fatalf("GenerateRequestSecret() error = %v", err)
	}

	envelope := models.EncryptedSessionEnvelope{
		Version:            1,
		Algorithm:          models.SessionEncryptionAlgorithmX25519XSalsa20Poly1305,
		EphemeralPublicKey: "ephemeral",
		Nonce:              "nonce",
		Ciphertext:         "ciphertext",
		CapturedAt:         models.NewISO8601Time(time.Unix(1_775_000_001, 0)),
	}

	signature, err := ComputeEnvelopeProof("r_test", envelope, secret)
	if err != nil {
		t.Fatalf("ComputeEnvelopeProof() error = %v", err)
	}

	envelope.RequestSignature = signature
	if err := VerifyEnvelopeProof("r_test", envelope, secret); err != nil {
		t.Fatalf("VerifyEnvelopeProof() error = %v", err)
	}

	envelope.Ciphertext = "ciphertext-mutated"
	if err := VerifyEnvelopeProof("r_test", envelope, secret); err == nil {
		t.Fatal("VerifyEnvelopeProof() should fail after payload mutation")
	}
}
