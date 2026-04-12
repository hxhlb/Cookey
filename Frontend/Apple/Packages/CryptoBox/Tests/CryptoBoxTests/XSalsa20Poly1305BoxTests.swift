import Clibsodium
@testable import CryptoBox
import Foundation
import Sodium
import Testing

@Test
func `seal/open round-trip stays compatible with shared-secret open`() throws {
    let sodium = Sodium()
    let recipient = try #require(sodium.box.keyPair())

    let plaintext = Data("cookey-session".utf8)
    let sealed = try XSalsa20Poly1305Box.seal(
        plaintext: plaintext,
        recipientPublicKey: Data(recipient.publicKey),
    )

    var sharedSecret = [UInt8](repeating: 0, count: Int(crypto_scalarmult_bytes()))
    var recipientSecretKey = recipient.secretKey
    var ephemeralPublicKey = [UInt8](sealed.ephemeralPublicKey)

    #expect(
        crypto_scalarmult(
            &sharedSecret,
            &recipientSecretKey,
            &ephemeralPublicKey,
        ) == 0,
    )

    let opened = try XSalsa20Poly1305Box.open(
        ciphertext: sealed.ciphertext,
        nonce: sealed.nonce,
        sharedSecret: Data(sharedSecret),
    )

    #expect(opened == plaintext)
}
