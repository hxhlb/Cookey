@testable import Cookey
import Foundation
import Testing

struct DeepLinkTests {
    @Test
    func `PairKeyDeepLink parses host-only HTTPS format`() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=api.cookey.sh"))

        let deepLink = try #require(PairKeyDeepLink(url: url))
        #expect(deepLink.pairKey == "SM8ND67N")
        #expect(deepLink.serverURL == URL(string: "https://api.cookey.sh"))
    }

    @Test
    func `PairKeyDeepLink uses default server when host is omitted`() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N"))

        let deepLink = try #require(PairKeyDeepLink(url: url))
        #expect(deepLink.pairKey == "SM8ND67N")
        #expect(deepLink.serverURL == AppEnvironment.effectiveAPIBaseURL)
    }

    @Test
    func `PairKeyDeepLink rejects custom server paths`() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=api.cookey.sh/path"))
        #expect(PairKeyDeepLink(url: url) == nil)
    }

    @Test
    func `PairKeyDeepLink rejects server values with scheme`() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=https://api.cookey.sh"))
        #expect(PairKeyDeepLink(url: url) == nil)
    }
}
