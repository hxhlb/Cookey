@testable import Cookey
import Foundation
import Testing

@Suite(.serialized)
struct KeyFingerprintTests {
    // MARK: - Golden Fixtures (from Go implementation)

    private static let goldenKeyBase64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="
    private static let goldenFingerprint = "630d:cd29:66c4  🥗 🍹 🪀 🥒 🍪 🍧"
    private static let goldenHex = "630d:cd29:66c4"
    private static let goldenEmoji = "🥗 🍹 🪀 🥒 🍪 🍧"
    private static let goldenEmojiTableChecksum = "b095fe8df1b34c713e3f25683a031536567c5a31d961a80035e9c3e973d2024e"

    // MARK: - KeyFingerprint Tests

    @Test
    func `Golden fixture: compute matches expected fingerprint from Go implementation`() throws {
        let fingerprint = try KeyFingerprint.compute(fromX25519PublicKeyBase64: Self.goldenKeyBase64)
        #expect(fingerprint == Self.goldenFingerprint)

        // Also verify the hex and emoji portions individually
        let parts = fingerprint.components(separatedBy: "  ")
        let hex = try #require(parts.first)
        let emoji = try #require(parts.last)
        #expect(hex == Self.goldenHex)
        #expect(emoji == Self.goldenEmoji)
    }

    @Test
    func `Emoji table checksum matches Go implementation`() {
        let checksum = KeyFingerprint.emojiTableChecksum()
        #expect(checksum == Self.goldenEmojiTableChecksum)
    }

    @Test
    func `Empty string throws invalidPublicKey`() {
        #expect(throws: KeyFingerprintError.invalidPublicKey) {
            try KeyFingerprint.compute(fromX25519PublicKeyBase64: "")
        }
    }

    @Test
    func `Invalid base64 throws invalidPublicKey`() {
        #expect(throws: KeyFingerprintError.invalidPublicKey) {
            try KeyFingerprint.compute(fromX25519PublicKeyBase64: "not-valid-base64!!!")
        }
    }

    @Test
    func `Wrong-length key throws invalidPublicKey`() {
        // 16 bytes instead of 32
        let shortKey = Data(repeating: 0xAB, count: 16).base64EncodedString()
        #expect(throws: KeyFingerprintError.invalidPublicKey) {
            try KeyFingerprint.compute(fromX25519PublicKeyBase64: shortKey)
        }

        // 64 bytes instead of 32
        let longKey = Data(repeating: 0xAB, count: 64).base64EncodedString()
        #expect(throws: KeyFingerprintError.invalidPublicKey) {
            try KeyFingerprint.compute(fromX25519PublicKeyBase64: longKey)
        }
    }

    @Test
    func `Deterministic: same key always produces same fingerprint`() throws {
        let first = try KeyFingerprint.compute(fromX25519PublicKeyBase64: Self.goldenKeyBase64)
        let second = try KeyFingerprint.compute(fromX25519PublicKeyBase64: Self.goldenKeyBase64)
        let third = try KeyFingerprint.compute(fromX25519PublicKeyBase64: Self.goldenKeyBase64)
        #expect(first == second)
        #expect(second == third)
    }

    // MARK: - TrustedKeyStore Tests

    private static let testDeviceA = "test-device-a-\(UUID().uuidString)"
    private static let testDeviceB = "test-device-b-\(UUID().uuidString)"
    private static let testKeyA = Data(repeating: 0x01, count: 32).base64EncodedString()
    private static let testKeyB = Data(repeating: 0x02, count: 32).base64EncodedString()

    @Test
    func `verify returns .firstTime for unknown device and key`() {
        let deviceID = "first-time-\(UUID().uuidString)"
        let key = Data(repeating: 0xAA, count: 32).base64EncodedString()

        defer { TrustedKeyStore.remove(deviceID: deviceID) }

        let state = TrustedKeyStore.verify(deviceID: deviceID, publicKeyBase64: key)
        guard case .firstTime = state else {
            Issue.record("Expected .firstTime, got \(state)")
            return
        }
    }

    @Test
    func `verify returns .trusted after trust() with same device and key`() throws {
        let deviceID = Self.testDeviceA
        let key = Self.testKeyA
        let fingerprint = try KeyFingerprint.compute(fromX25519PublicKeyBase64: key)

        defer { TrustedKeyStore.remove(deviceID: deviceID) }

        TrustedKeyStore.trust(deviceID: deviceID, publicKeyBase64: key, fingerprint: fingerprint)

        let state = TrustedKeyStore.verify(deviceID: deviceID, publicKeyBase64: key)
        guard case .trusted = state else {
            Issue.record("Expected .trusted, got \(state)")
            return
        }
    }

    @Test
    func `verify returns .keyChanged when same deviceID but different key`() throws {
        let deviceID = "key-changed-\(UUID().uuidString)"
        let originalKey = Self.testKeyA
        let newKey = Self.testKeyB
        let originalFingerprint = try KeyFingerprint.compute(fromX25519PublicKeyBase64: originalKey)

        defer { TrustedKeyStore.remove(deviceID: deviceID) }

        TrustedKeyStore.trust(
            deviceID: deviceID,
            publicKeyBase64: originalKey,
            fingerprint: originalFingerprint,
        )

        let state = TrustedKeyStore.verify(deviceID: deviceID, publicKeyBase64: newKey)
        guard case .keyChanged = state else {
            Issue.record("Expected .keyChanged, got \(state)")
            return
        }
    }

    @Test
    func `verify returns .knownKeyNewDevice when different deviceID but same key`() throws {
        let deviceA = "known-key-a-\(UUID().uuidString)"
        let deviceB = "known-key-b-\(UUID().uuidString)"
        let sharedKey = Self.testKeyA
        let fingerprint = try KeyFingerprint.compute(fromX25519PublicKeyBase64: sharedKey)

        defer {
            TrustedKeyStore.remove(deviceID: deviceA)
            TrustedKeyStore.remove(deviceID: deviceB)
        }

        TrustedKeyStore.trust(
            deviceID: deviceA,
            publicKeyBase64: sharedKey,
            fingerprint: fingerprint,
        )

        let state = TrustedKeyStore.verify(deviceID: deviceB, publicKeyBase64: sharedKey)
        guard case .knownKeyNewDevice = state else {
            Issue.record("Expected .knownKeyNewDevice, got \(state)")
            return
        }
    }
}
