package qrcode

import (
	"bytes"
	"net/url"

	qrterminal "github.com/mdp/qrterminal/v3"
)

func PairKeyDeepLink(pairKey string, serverURL string, requestSecret string) string {
	components := url.URL{
		Scheme: "cookey",
		Host:   "p",
		Path:   "/" + pairKey,
	}
	query := url.Values{}
	query.Set("s", requestSecret)
	if serverURL != "" && serverURL != DefaultServerURL {
		query.Set("h", serverURL)
	}
	components.RawQuery = query.Encode()
	return components.String()
}

var DefaultServerURL = "https://api.cookey.sh"

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
