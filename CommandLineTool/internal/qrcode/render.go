package qrcode

import (
	"bytes"
	"net/url"

	qrterminal "github.com/mdp/qrterminal/v3"

	"cookey/internal/models"
)

func DeepLink(manifest models.LoginManifest) string {
	components := url.URL{
		Scheme: "cookey",
		Host:   "login",
	}
	query := url.Values{}
	query.Set("rid", manifest.RID)
	query.Set("server", manifest.ServerURL)
	query.Set("target", manifest.TargetURL)
	query.Set("pubkey", manifest.CLIPublicKey)
	query.Set("device_id", manifest.DeviceID)
	query.Set("expires_at", manifest.ExpiresAt.Time.UTC().Format("2006-01-02T15:04:05Z"))
	query.Set("request_proof", manifest.RequestProof)
	query.Set("request_secret", manifest.RequestSecret)
	if manifest.RequestType != "" {
		query.Set("request_type", manifest.RequestType)
	}
	components.RawQuery = query.Encode()
	return components.String()
}

func PairKeyDeepLink(pairKey string, serverURL string, requestSecret string) string {
	components := url.URL{
		Scheme: "cookey",
		Host:   "login",
	}
	query := url.Values{}
	query.Set("pair", pairKey)
	query.Set("server", serverURL)
	query.Set("request_secret", requestSecret)
	components.RawQuery = query.Encode()
	return components.String()
}

func Render(link string) string {
	var output bytes.Buffer
	config := qrterminal.Config{
		Level:          qrterminal.L,
		Writer:         &output,
		HalfBlocks:     true,
		BlackChar:      qrterminal.BLACK_BLACK,
		BlackWhiteChar: qrterminal.BLACK_WHITE,
		WhiteChar:      qrterminal.WHITE_WHITE,
		WhiteBlackChar: qrterminal.WHITE_BLACK,
		QuietZone:      0,
	}
	qrterminal.GenerateWithConfig(link, config)
	return output.String()
}
