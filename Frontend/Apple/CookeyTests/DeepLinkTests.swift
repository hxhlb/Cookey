@testable import Cookey
import Foundation
import Testing

struct DeepLinkTests {
    @Test("PairKeyDeepLink parses host-only HTTPS format")
    func parsesPairKeyDeepLink() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=api.cookey.sh"))

        let deepLink = try #require(PairKeyDeepLink(url: url))
        #expect(deepLink.pairKey == "SM8ND67N")
        #expect(deepLink.serverURL == URL(string: "https://api.cookey.sh"))
    }

    @Test("PairKeyDeepLink uses default server when host is omitted")
    func parsesPairKeyDeepLinkWithoutHost() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N"))

        let deepLink = try #require(PairKeyDeepLink(url: url))
        #expect(deepLink.pairKey == "SM8ND67N")
        #expect(deepLink.serverURL == AppEnvironment.effectiveAPIBaseURL)
    }

    @Test("PairKeyDeepLink rejects custom server paths")
    func rejectsPairKeyDeepLinkWithPath() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=api.cookey.sh/path"))
        #expect(PairKeyDeepLink(url: url) == nil)
    }

    @Test("PairKeyDeepLink rejects server values with scheme")
    func rejectsPairKeyDeepLinkWithScheme() throws {
        let url = try #require(URL(string: "cookey://SM8ND67N?host=https://api.cookey.sh"))
        #expect(PairKeyDeepLink(url: url) == nil)
    }
}
