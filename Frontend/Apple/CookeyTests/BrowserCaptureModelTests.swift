@testable import Cookey
import Foundation
import Testing

@MainActor
struct BrowserCaptureModelTests {
    @Test("BrowserCaptureModel maps captured cookies to HTTPCookie with sameSite")
    func mapsCapturedCookies() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "session",
                value: "abc123",
                domain: ".example.com",
                path: "/",
                expires: 1_800_000_000,
                httpOnly: true,
                secure: true,
                sameSite: "Strict"
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

    @Test("BrowserCaptureModel builds origin-filtered localStorage injection script with escaping")
    func buildsLocalStorageInjectionScript() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [
                    CapturedStorageItem(name: "quote\"key", value: "line1\nline2"),
                    CapturedStorageItem(name: "json", value: #"{"enabled":true}"#),
                ]
            ),
            CapturedOrigin(
                origin: "https://ignored.example.com",
                localStorage: []
            ),
        ]))

        #expect(script.contains(#"if(window.location.origin==="https:\/\/example.com")"#))
        #expect(script.contains(#"window.localStorage.setItem("quote\"key","line1\nline2")"#))
        #expect(script.contains(#"window.localStorage.setItem("json","{\"enabled\":true}")"#))
        #expect(!script.contains("ignored.example.com"))
    }

    // MARK: - httpCookies edge cases

    @Test("httpCookies returns empty array for empty input")
    func httpCookiesEmpty() {
        let cookies = BrowserCaptureModel.httpCookies(from: [])
        #expect(cookies.isEmpty)
    }

    @Test("httpCookies skips expired cookies with negative expires")
    func httpCookiesNegativeExpires() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "token",
                value: "xyz",
                domain: ".example.com",
                path: "/",
                expires: -1,
                httpOnly: false,
                secure: false,
                sameSite: "Lax"
            ),
        ])

        let cookie = try #require(cookies.first)
        #expect(cookie.name == "token")
        #expect(cookie.expiresDate == nil)
    }

    @Test("httpCookies maps httpOnly property")
    func httpCookiesHttpOnly() throws {
        let cookies = BrowserCaptureModel.httpCookies(from: [
            CapturedCookie(
                name: "secret",
                value: "val",
                domain: ".test.com",
                path: "/api",
                expires: 0,
                httpOnly: true,
                secure: false,
                sameSite: ""
            ),
        ])

        let cookie = try #require(cookies.first)
        #expect(cookie.isHTTPOnly)
        #expect(cookie.path == "/api")
    }

    @Test("httpCookies maps multiple cookies preserving order")
    func httpCookiesMultiple() {
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

    @Test("localStorageInjectionScript returns nil for empty origins")
    func localStorageScriptEmptyOrigins() {
        let script = BrowserCaptureModel.localStorageInjectionScript(from: [])
        #expect(script == nil)
    }

    @Test("localStorageInjectionScript returns nil when all origins have empty localStorage")
    func localStorageScriptAllEmpty() {
        let script = BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(origin: "https://example.com", localStorage: []),
            CapturedOrigin(origin: "https://other.com", localStorage: []),
        ])
        #expect(script == nil)
    }

    @Test("localStorageInjectionScript handles multiple origins")
    func localStorageScriptMultipleOrigins() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://alpha.com",
                localStorage: [CapturedStorageItem(name: "k1", value: "v1")]
            ),
            CapturedOrigin(
                origin: "https://beta.com",
                localStorage: [CapturedStorageItem(name: "k2", value: "v2")]
            ),
        ]))

        #expect(script.contains("alpha.com"))
        #expect(script.contains("beta.com"))
        #expect(script.contains(#"window.localStorage.setItem("k1","v1")"#))
        #expect(script.contains(#"window.localStorage.setItem("k2","v2")"#))
    }

    @Test("localStorageInjectionScript wraps each setItem in try-catch")
    func localStorageScriptTryCatch() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [CapturedStorageItem(name: "k", value: "v")]
            ),
        ]))

        #expect(script.contains("try{window.localStorage.setItem"))
        #expect(script.contains("}catch(e){}"))
    }

    @Test("localStorageInjectionScript escapes special characters in keys and values")
    func localStorageScriptSpecialChars() throws {
        let script = try #require(BrowserCaptureModel.localStorageInjectionScript(from: [
            CapturedOrigin(
                origin: "https://example.com",
                localStorage: [
                    CapturedStorageItem(name: "tab\there", value: "back\\slash"),
                    CapturedStorageItem(name: "<script>", value: "</script>"),
                ]
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
