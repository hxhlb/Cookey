@testable import Cookey
import Foundation
import Testing

struct DeepLinkTests {
    @Test("DeepLink defaults request_type to login")
    func defaultsRequestTypeToLogin() throws {
        let url = try #require(
            URL(string: "cookey://login?rid=r_default&server=https%3A%2F%2Fapi.cookey.sh&target=https%3A%2F%2Fexample.com&pubkey=abc123&device_id=device-default&expires_at=2026-04-02T12%3A00%3A00Z&request_proof=proof&request_secret=secret")
        )

        let deepLink = try #require(DeepLink(url: url))
        #expect(deepLink.requestType == .login)
    }

    @Test("DeepLink parses request_type refresh")
    func parsesRefreshRequestType() throws {
        let url = try #require(
            URL(string: "cookey://login?rid=r_refresh&server=https%3A%2F%2Fapi.cookey.sh&target=https%3A%2F%2Fexample.com&pubkey=abc123&device_id=device-refresh&request_type=refresh&expires_at=2026-04-02T12%3A00%3A00Z&request_proof=proof&request_secret=secret")
        )

        let deepLink = try #require(DeepLink(url: url))
        #expect(deepLink.requestType == .refresh)
    }

    @Test("DeepLink rejects non-local http relay URLs")
    func rejectsRemoteHTTPRelay() throws {
        let url = try #require(
            URL(string: "cookey://login?rid=r_http&server=http%3A%2F%2Frelay.example.com&target=https%3A%2F%2Fexample.com&pubkey=abc123&device_id=device-http&expires_at=2026-04-02T12%3A00%3A00Z&request_proof=proof&request_secret=secret")
        )

        #expect(DeepLink(url: url) == nil)
    }
}
