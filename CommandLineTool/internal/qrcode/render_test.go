package qrcode

import "testing"

func TestPairKeyDeepLinkUsesHostOnlyFormat(t *testing.T) {
	link := PairKeyDeepLink("SM8ND67N", "https://api.cookey.sh")
	if link != "cookey://SM8ND67N?host=api.cookey.sh" {
		t.Fatalf("link = %q", link)
	}
}

func TestRelayHostDropsSchemeAndPath(t *testing.T) {
	host := RelayHost("https://api.cookey.sh:8443/")
	if host != "api.cookey.sh:8443" {
		t.Fatalf("host = %q", host)
	}
}
