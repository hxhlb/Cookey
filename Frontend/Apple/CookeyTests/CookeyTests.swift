import Clibsodium
@testable import Cookey
import CryptoBox
import Foundation
import Sodium
import Testing

private struct RecordedRequest {
    let method: String?
    let url: URL?
    let body: Data?
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

@Suite(.serialized)
@MainActor
struct CookeyTests {
    @Test
    func `DeepLink verifies with valid proof and secret`() throws {
        let expiresAt = try #require(ISO8601DateFormatter().date(from: "2026-04-02T12:00:00Z"))
        let serverURL = try #require(URL(string: "https://api.cookey.sh"))
        let targetURL = try #require(URL(string: "https://www.qaq.wiki/wp-admin"))
        let requestSecret = Data(repeating: 0x42, count: 32)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let requestProof = try RequestAuthenticator.requestProof(
            rid: "r_123",
            serverURL: serverURL,
            targetURL: targetURL,
            recipientPublicKeyBase64: "U/uenIM6CaBBb3VLlp94N44EPuF8vQacUuzRfo27Lxk=",
            deviceID: "device-123",
            requestType: .login,
            expiresAt: expiresAt,
            requestSecret: requestSecret,
        )

        let deepLink = DeepLink(
            rid: "r_123",
            serverURL: serverURL,
            targetURL: targetURL,
            recipientPublicKeyBase64: "U/uenIM6CaBBb3VLlp94N44EPuF8vQacUuzRfo27Lxk=",
            deviceID: "device-123",
            requestType: .login,
            expiresAt: expiresAt,
            requestProof: requestProof,
            requestSecret: requestSecret,
        )
        #expect(deepLink.rid == "r_123")
        #expect(deepLink.serverURL == serverURL)
        #expect(deepLink.targetURL == targetURL)
        #expect(deepLink.recipientPublicKeyBase64 == "U/uenIM6CaBBb3VLlp94N44EPuF8vQacUuzRfo27Lxk=")
        #expect(deepLink.deviceID == "device-123")
        #expect(deepLink.requestType == .login)
        try RequestAuthenticator.verify(deepLink)
    }

    @Test(
        arguments: [
            Data(),
            Data("{}".utf8),
            Data(#"{"cookies":[]}"#.utf8),
            Data(#"{"origins":[]}"#.utf8),
            Data("[]".utf8),
        ],
    )
    func `validateCapturedSessionData rejects malformed payloads`(_ payload: Data) throws {
        #expect(throws: Error.self) {
            try SessionUploadModel.validateCapturedSessionData(payload)
        }
    }

    @Test
    func `validateCapturedSessionData accepts cookies + origins payload`() throws {
        let payload = Data(
            #"""
            {
              "cookies": [
                {
                  "name": "wordpress_test_cookie",
                  "value": "WP%20Cookie%20check",
                  "domain": "www.qaq.wiki",
                  "path": "/",
                  "expires": -1,
                  "httpOnly": true,
                  "secure": true,
                  "sameSite": "Lax"
                }
              ],
              "origins": [
                {
                  "origin": "https://www.qaq.wiki",
                  "localStorage": [
                    {
                      "name": "dracula_mode",
                      "value": "dark"
                    }
                  ]
                }
              ]
            }
            """#.utf8,
        )

        try SessionUploadModel.validateCapturedSessionData(payload)
    }

    @Test
    func `encodeCapturedSession preserves browser session JSON`() throws {
        let capturedSession = CapturedSession(
            cookies: [
                CapturedCookie(
                    name: "wordpress_test_cookie",
                    value: "WP%20Cookie%20check",
                    domain: "www.qaq.wiki",
                    path: "/",
                    expires: -1,
                    httpOnly: true,
                    secure: true,
                    sameSite: "Lax",
                ),
                CapturedCookie(
                    name: "cf_clearance",
                    value: "token",
                    domain: ".qaq.wiki",
                    path: "/",
                    expires: 1_806_582_709,
                    httpOnly: true,
                    secure: true,
                    sameSite: "Lax",
                ),
            ],
            origins: [
                CapturedOrigin(
                    origin: "https://www.qaq.wiki",
                    localStorage: [
                        CapturedStorageItem(name: "dracula_mode", value: "dark"),
                    ],
                ),
            ],
            deviceInfo: nil,
        )

        let payload = try SessionUploadModel.encodeCapturedSession(capturedSession)
        let decoded = try JSONDecoder().decode(CapturedSession.self, from: payload)

        #expect(payload.count > 100)
        #expect(decoded == capturedSession)
    }

    @Test
    func `uploadCapturedSessionData posts decryptable envelope`() async throws {
        let sodium = Sodium()
        let recipient = try #require(sodium.box.keyPair())
        let serverURL = try #require(URL(string: "https://api.cookey.test/\(UUID().uuidString)"))
        let requestSecret = Data(repeating: 0x24, count: 32)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let expiresAt = try #require(ISO8601DateFormatter().date(from: "2026-04-02T12:00:00Z"))
        let requestProof = try RequestAuthenticator.requestProof(
            rid: "r_test_upload",
            serverURL: serverURL,
            targetURL: #require(URL(string: "https://www.qaq.wiki/wp-admin")),
            recipientPublicKeyBase64: Data(recipient.publicKey).base64EncodedString(),
            deviceID: "device-test",
            requestType: .login,
            expiresAt: expiresAt,
            requestSecret: requestSecret,
        )

        let deepLink = try DeepLink(
            rid: "r_test_upload",
            serverURL: serverURL,
            targetURL: #require(URL(string: "https://www.qaq.wiki/wp-admin")),
            recipientPublicKeyBase64: Data(recipient.publicKey).base64EncodedString(),
            deviceID: "device-test",
            requestType: .login,
            expiresAt: expiresAt,
            requestProof: requestProof,
            requestSecret: requestSecret,
        )

        let capturedSession = CapturedSession(
            cookies: [
                CapturedCookie(
                    name: "wordpress_test_cookie",
                    value: "WP%20Cookie%20check",
                    domain: "www.qaq.wiki",
                    path: "/",
                    expires: -1,
                    httpOnly: true,
                    secure: true,
                    sameSite: "Lax",
                ),
                CapturedCookie(
                    name: "cf_clearance",
                    value: "token",
                    domain: ".qaq.wiki",
                    path: "/",
                    expires: 1_806_582_709,
                    httpOnly: true,
                    secure: true,
                    sameSite: "Lax",
                ),
            ],
            origins: [
                CapturedOrigin(
                    origin: "https://www.qaq.wiki",
                    localStorage: [
                        CapturedStorageItem(name: "dracula_mode", value: "dark"),
                    ],
                ),
            ],
            deviceInfo: nil,
        )
        let plaintext = try SessionUploadModel.encodeCapturedSession(capturedSession)

        let requestBox = LockedBox<RecordedRequest?>(nil)

        NotificationPromptStore.store(.accepted, for: serverURL)

        let model = SessionUploadModel(
            pushCoordinator: nil,
            relayClientFactory: { baseURL in
                RelayClient(
                    baseURL: baseURL,
                    requestExecutor: { request in
                        let recordedRequest = RecordedRequest(
                            method: request.httpMethod,
                            url: request.url,
                            body: request.httpBody,
                        )
                        requestBox.withLock { $0 = recordedRequest }
                        let response = HTTPURLResponse(
                            url: baseURL,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"],
                        )!
                        return (Data(), response)
                    },
                )
            },
        )
        await model.uploadCapturedSessionData(plaintext, deepLink: deepLink)

        let request = try #require(requestBox.withLock { $0 })
        #expect(request.method == "POST")
        #expect(request.url?.path == "\(serverURL.path)/v1/requests/\(deepLink.rid)/session")
        let body = try #require(request.body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(EncryptedSessionEnvelope.self, from: body)
        let ciphertext = try #require(Data(base64Encoded: envelope.ciphertext))
        let nonce = try #require(Data(base64Encoded: envelope.nonce))
        let ephemeralPublicKey = try #require(Data(base64Encoded: envelope.ephemeralPublicKey))
        let requestSignature = try #require(envelope.requestSignature)
        let expectedRequestSignature = try RequestAuthenticator.envelopeProof(
            rid: deepLink.rid,
            envelope: EncryptedSessionEnvelope(
                version: envelope.version,
                algorithm: envelope.algorithm,
                ephemeralPublicKey: envelope.ephemeralPublicKey,
                nonce: envelope.nonce,
                ciphertext: envelope.ciphertext,
                capturedAt: envelope.capturedAt,
                requestSignature: nil,
            ),
            requestSecret: requestSecret,
        )

        var sharedSecret = [UInt8](repeating: 0, count: Int(crypto_scalarmult_bytes()))
        var recipientSecretKey = recipient.secretKey
        var ephemeralPublicKeyBytes = [UInt8](ephemeralPublicKey)
        #expect(
            crypto_scalarmult(
                &sharedSecret,
                &recipientSecretKey,
                &ephemeralPublicKeyBytes,
            ) == 0,
        )

        let opened = try XSalsa20Poly1305Box.open(
            ciphertext: ciphertext,
            nonce: nonce,
            sharedSecret: Data(sharedSecret),
        )

        #expect(envelope.version == 1)
        #expect(envelope.algorithm == "x25519-xsalsa20poly1305")
        #expect(opened == plaintext)
        #expect(requestSignature == expectedRequestSignature)
        #expect(model.phase == SessionUploadModel.Phase.done)
    }

    @Test
    func `PushRegistrationCoordinator stores token for waiting registration`() async throws {
        PushTokenStore.currentToken = nil
        PushTokenStore.currentEnvironment = nil
        let coordinator = PushRegistrationCoordinator()

        let serverURL = try #require(URL(string: "https://relay.cookey.test"))
        coordinator.state = .waitingForToken(serverURL: serverURL, deviceID: "device-1")

        await coordinator.handleRegisteredDeviceToken(Data([0x01, 0x02, 0x03]))

        #expect(PushTokenStore.currentToken == "010203")
        #expect(PushTokenStore.currentEnvironment != nil)
        #expect(coordinator.state == .idle)
    }

    @Test
    func `PushRegistrationCoordinator refreshes stored token without relay registration`() async {
        PushTokenStore.currentToken = nil
        PushTokenStore.currentEnvironment = nil
        let coordinator = PushRegistrationCoordinator()

        await coordinator.handleRegisteredDeviceToken(Data([0xAA, 0xBB]))

        #expect(PushTokenStore.currentToken == "aabb")
    }
}
