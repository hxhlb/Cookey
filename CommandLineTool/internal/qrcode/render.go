package qrcode

import (
	"bytes"
	"net/url"

	qrterminal "github.com/mdp/qrterminal/v3"
)

func CookeyLink(pairKey string, serverURL string) string {
	components := url.URL{
		Scheme: "cookey",
		Host:   pairKey,
	}
	if !IsDefaultServer(serverURL) {
		query := url.Values{}
		query.Set("host", RelayHost(serverURL))
		components.RawQuery = query.Encode()
	}
	return components.String()
}

func JumpLink(pairKey string, serverURL string) string {
	host := RelayHost(serverURL)
	code := pairKey
	if len(pairKey) >= 5 {
		code = pairKey[:4] + "-" + pairKey[4:]
	}
	return "https://" + host + "/jump?code=" + code
}

func IsDefaultServer(serverURL string) bool {
	return RelayHost(serverURL) == RelayHost(DefaultServerURL)
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
