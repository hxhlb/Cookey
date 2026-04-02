package qrcode

import (
	"bytes"
	"net/url"

	qrterminal "github.com/mdp/qrterminal/v3"
)

func PairKeyDeepLink(pairKey string, serverURL string) string {
	components := url.URL{
		Scheme: "cookey",
		Host:   pairKey,
	}
	query := url.Values{}
	query.Set("host", RelayHost(serverURL))
	components.RawQuery = query.Encode()
	return components.String()
}

func RelayHost(serverURL string) string {
	parsed, err := url.Parse(serverURL)
	if err != nil || parsed.Host == "" {
		return serverURL
	}
	return parsed.Host
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
