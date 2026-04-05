package qrcode

import "testing"

func TestCookeyLinkDefaultServer(t *testing.T) {
	link := CookeyLink("SM8ND67N", "https://api.cookey.sh")
	if link != "cookey://SM8ND67N" {
		t.Fatalf("link = %q", link)
	}
}

func TestCookeyLinkCustomServer(t *testing.T) {
	link := CookeyLink("SM8ND67N", "https://custom.host:8443")
	if link != "cookey://SM8ND67N?host=custom.host%3A8443" {
		t.Fatalf("link = %q", link)
	}
}

func TestJumpLinkDefaultServer(t *testing.T) {
	link := JumpLink("SM8ND67N", "https://api.cookey.sh")
	if link != "https://api.cookey.sh/jump?code=SM8N-D67N" {
		t.Fatalf("link = %q", link)
	}
}

func TestJumpLinkCustomServer(t *testing.T) {
	link := JumpLink("SM8ND67N", "https://custom.host:8443")
	if link != "https://custom.host:8443/jump?code=SM8N-D67N" {
		t.Fatalf("link = %q", link)
	}
}

func TestJumpLinkShortPairKey(t *testing.T) {
	link := JumpLink("ABC", "https://api.cookey.sh")
	if link != "https://api.cookey.sh/jump?code=ABC" {
		t.Fatalf("link = %q", link)
	}
}

func TestRelayHostDropsSchemeAndPath(t *testing.T) {
	host := RelayHost("https://api.cookey.sh:8443/")
	if host != "api.cookey.sh:8443" {
		t.Fatalf("host = %q", host)
	}
}
