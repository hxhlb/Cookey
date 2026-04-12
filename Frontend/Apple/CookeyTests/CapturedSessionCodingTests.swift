@testable import Cookey
import Foundation
import Testing

@MainActor
struct CapturedSessionCodingTests {
    @Test
    func `CapturedSession coding preserves device_info when present`() throws {
        let session = CapturedSession(
            cookies: [
                CapturedCookie(
                    name: "session",
                    value: "abc",
                    domain: "example.com",
                    path: "/",
                    expires: -1,
                    httpOnly: true,
                    secure: true,
                    sameSite: "Lax",
                ),
            ],
            origins: [
                CapturedOrigin(
                    origin: "https://example.com",
                    localStorage: [CapturedStorageItem(name: "token", value: "value")],
                ),
            ],
            deviceInfo: DeviceInfo(
                deviceID: "device-123",
                apnToken: "token-123",
                apnEnvironment: "sandbox",
                publicKey: "public-key",
            ),
        )

        let data = try JSONEncoder().encode(session)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"device_info\""))
        #expect(json.contains("\"apn_token\""))
        #expect(json.contains("\"public_key\""))

        let decoded = try JSONDecoder().decode(CapturedSession.self, from: data)
        #expect(decoded == session)
    }

    @Test
    func `CapturedSession coding omits device_info when absent`() throws {
        let session = CapturedSession(
            cookies: [],
            origins: [],
            deviceInfo: nil,
        )

        let data = try JSONEncoder().encode(session)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("\"device_info\""))

        let decoded = try JSONDecoder().decode(CapturedSession.self, from: data)
        #expect(decoded.deviceInfo == nil)
        #expect(decoded.cookies.isEmpty)
        #expect(decoded.origins.isEmpty)
    }

    @Test
    func `CapturedSession decoding treats null localStorage as empty array`() throws {
        let payload = """
        {
          "cookies": [],
          "origins": [
            {
              "origin": "https://example.com",
              "localStorage": null
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(CapturedSession.self, from: Data(payload.utf8))
        #expect(decoded.origins.count == 1)
        #expect(decoded.origins[0].origin == "https://example.com")
        #expect(decoded.origins[0].localStorage.isEmpty)
    }

    @Test
    func `CapturedSession decoding treats null cookies as empty array`() throws {
        let payload = """
        {
          "cookies": null,
          "origins": []
        }
        """

        let decoded = try JSONDecoder().decode(CapturedSession.self, from: Data(payload.utf8))
        #expect(decoded.cookies.isEmpty)
        #expect(decoded.origins.isEmpty)
    }

    @Test
    func `CapturedCookie decoding defaults null fields`() throws {
        let payload = """
        {
          "cookies": [
            {
              "name": "session",
              "value": "abc",
              "domain": "example.com",
              "path": null,
              "expires": null,
              "httpOnly": null,
              "secure": null,
              "sameSite": null
            }
          ],
          "origins": []
        }
        """

        let decoded = try JSONDecoder().decode(CapturedSession.self, from: Data(payload.utf8))
        let cookie = try #require(decoded.cookies.first)
        #expect(cookie.path == "/")
        #expect(cookie.expires == -1)
        #expect(cookie.httpOnly == false)
        #expect(cookie.secure == false)
        #expect(cookie.sameSite.isEmpty)
    }
}
