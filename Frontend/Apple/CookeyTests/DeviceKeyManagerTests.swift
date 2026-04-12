@testable import Cookey
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct DeviceKeyManagerTests {
    @Test
    func `DeviceKeyManager generates and persists a 32-byte X25519 key pair`() throws {
        try DeviceKeyManager.removeAll()
        defer {
            try? DeviceKeyManager.removeAll()
        }

        let first = try DeviceKeyManager.loadOrCreateKeyPair()
        let second = try DeviceKeyManager.loadOrCreateKeyPair()

        #expect(first.publicKey.count == 32)
        #expect(first.secretKey.count == 32)
        #expect(first == second)
        #expect(try DeviceKeyManager.publicKey() == first.publicKey)
        #expect(try DeviceKeyManager.secretKey() == first.secretKey)
    }
}
