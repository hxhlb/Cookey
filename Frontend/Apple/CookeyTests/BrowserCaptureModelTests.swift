@testable import Cookey
import Foundation
import Testing

@MainActor
struct BrowserCaptureModelTests {
    @Test
    func `BrowserCaptureModel maps captured cookies to HTTPCookie with sameSite`() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "session",
                value: "abc123",
                domain: ".example.com",
                path: "/",
                expires: 1_800_000_000,
                httpOnly: true,
                secure: true,
                sameSite: "Strict",
            ),
        ])

        let cookie = try #require(cookies.first)
        #expect(cookie.name == "session")
        #expect(cookie.value == "abc123")
        #expect(cookie.domain == ".example.com")
        #expect(cookie.path == "/")
        #expect(cookie.isSecure)
        #expect(cookie.expiresDate == Date(timeIntervalSince1970: 1_800_000_000))
        #expect((cookie.properties?[.sameSitePolicy] as? String) == "strict")
    }

    @Test
    func `BrowserCaptureModel builds origin-filtered localStorage injection script with escaping`() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [
                    CapturedStorageItem(name: "quote\"key", value: "line1\nline2"),
                    CapturedStorageItem(name: "json", value: #"{"enabled":true}"#),
                ],
            ),
            CapturedOrigin(
                origin: "https://ignored.example.com",
                localStorage: [],
            ),
        ]))

        #expect(script.contains(#"if(window.location.origin==="https:\/\/example.com")"#))
        #expect(script.contains(#"window.localStorage.setItem("quote\"key","line1\nline2")"#))
        #expect(script.contains(#"window.localStorage.setItem("json","{\"enabled\":true}")"#))
        #expect(!script.contains("ignored.example.com"))
    }

    // MARK: - httpCookies edge cases

    @Test
    func `httpCookies returns empty array for empty input`() {
        let cookies = BrowserCaptureModel.httpCookies(from: [])
        #expect(cookies.isEmpty)
    }

    @Test
    func `httpCookies skips expired cookies with negative expires`() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "token",
                value: "xyz",
                domain: ".example.com",
                path: "/",
                expires: -1,
                httpOnly: false,
                secure: false,
                sameSite: "Lax",
            ),
        ])

        let cookie = try #require(cookies.first)
        #expect(cookie.name == "token")
        #expect(cookie.expiresDate == nil)
    }

    @Test
    func `httpCookies maps httpOnly property`() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "secret",
                value: "val",
                domain: ".test.com",
                path: "/api",
                expires: 0,
                httpOnly: true,
                secure: false,
                sameSite: "",
            ),
        ])

        let cookie = try #require(cookies.first)
        #expect(cookie.isHTTPOnly)
        #expect(cookie.path == "/api")
    }

    @Test
    func `httpCookies maps multiple cookies preserving order`() {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(name: "a", value: "1", domain: ".a.com", path: "/", expires: 0, httpOnly: false, secure: false, sameSite: ""),
            CapturedCookie(name: "b", value: "2", domain: ".b.com", path: "/", expires: 0, httpOnly: false, secure: true, sameSite: "None"),
            CapturedCookie(name: "c", value: "3", domain: ".c.com", path: "/x", expires: 1_700_000_000, httpOnly: true, secure: true, sameSite: "Strict"),
        ])

        #expect(cookies.count == 3)
        #expect(cookies[0].name == "a")
        #expect(cookies[1].name == "b")
        #expect(cookies[1].isSecure)
        #expect(cookies[2].name == "c")
        #expect(cookies[2].isHTTPOnly)
        #expect(cookies[2].isSecure)
    }

    // MARK: - localStorageInjectionScript edge cases

    @Test
    func `localStorageInjectionScript returns nil for empty origins`() {
        let script = BrowserCaptureModel.localStorageInjectionScript(from: [])
        #expect(script == nil)
    }

    @Test
    func `localStorageInjectionScript returns nil when all origins have empty localStorage`() {
        let script = BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(origin: "https://example.com", localStorage: []),
            CapturedOrigin(origin: "https://other.com", localStorage: []),
        ])
        #expect(script == nil)
    }

    @Test
    func `localStorageInjectionScript handles multiple origins`() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://alpha.com",
                localStorage: [CapturedStorageItem(name: "k1", value: "v1")],
            ),
            CapturedOrigin(
                origin: "https://beta.com",
                localStorage: [CapturedStorageItem(name: "k2", value: "v2")],
            ),
        ]))

        #expect(script.contains("alpha.com"))
        #expect(script.contains("beta.com"))
        #expect(script.contains(#"window.localStorage.setItem("k1","v1")"#))
        #expect(script.contains(#"window.localStorage.setItem("k2","v2")"#))
    }

    @Test
    func `localStorageInjectionScript wraps each setItem in try-catch`() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [CapturedStorageItem(name: "k", value: "v")],
            ),
        ]))

        #expect(script.contains("try{window.localStorage.setItem"))
        #expect(script.contains("}catch(e){}"))
    }

    @Test
    func `localStorageInjectionScript escapes special characters in keys and values`() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [
                    CapturedStorageItem(name: "tab\there", value: "back\\slash"),
                    CapturedStorageItem(name: "<script>", value: "</script>"),
                ],
            ),
        ]))

        // JSONSerialization escapes tabs and backslashes
        #expect(script.contains("\\t"))
        #expect(script.contains("\\\\"))
        // Angle brackets are preserved, while the closing tag slash is JSON-escaped.
        #expect(script.contains("<script>"))
        #expect(script.contains("<\\/script>"))
    }
}
