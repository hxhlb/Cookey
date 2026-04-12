import Clibsodium
import Foundation
import Sodium

public enum CryptoBoxError: Error {
    case invalidNonce
    case invalidCiphertext
    case authenticationFailed
    case invalidRecipientPublicKey
    case invalidEphemeralPublicKey
    case randomGenerationFailed
}

public enum XSalsa20Poly1305Box {
    private static let sodium = Sodium()
    private static let hsalsa20Constant = Array("expand 32-byte k".utf8)

    public static func open(ciphertext: Data, nonce: Data, sharedSecret: Data) throws -> Data {
        guard nonce.count == Int(crypto_secretbox_noncebytes()) else {
            throw CryptoBoxError.invalidNonce
        }

        guard ciphertext.count >= Int(crypto_secretbox_macbytes()) else {
            throw CryptoBoxError.invalidCiphertext
        }

        let secretBoxKey = try deriveSecretBoxKey(from: sharedSecret)
        guard let plaintext = sodium.secretBox.open(
            authenticatedCipherText: Array(ciphertext),
            secretKey: secretBoxKey,
            nonce: Array(nonce),
        ) else {
            throw CryptoBoxError.authenticationFailed
        }

        return Data(plaintext)
    }

    public static func open(
        ciphertext: Data,
        nonce: Data,
        ephemeralPublicKey: Data,
        recipientSecretKey: Data,
    ) throws -> Data {
        guard ephemeralPublicKey.count == Int(crypto_box_publickeybytes()) else {
            throw CryptoBoxError.invalidEphemeralPublicKey
        }

        guard nonce.count == Int(crypto_box_noncebytes()) else {
            throw CryptoBoxError.invalidNonce
        }

        guard ciphertext.count >= Int(crypto_box_macbytes()) else {
            throw CryptoBoxError.invalidCiphertext
        }

        let senderPublicKey = Array(ephemeralPublicKey)
        let recipientSecretKeyBytes = Array(recipientSecretKey)
        guard recipientSecretKeyBytes.count == sodium.box.SecretKeyBytes else {
            throw CryptoBoxError.invalidCiphertext
        }

        guard let plaintext = sodium.box.open(
            authenticatedCipherText: Array(ciphertext),
            senderPublicKey: senderPublicKey,
            recipientSecretKey: recipientSecretKeyBytes,
            nonce: Array(nonce),
        ) else {
            throw CryptoBoxError.authenticationFailed
        }

        return Data(plaintext)
    }

    public static func seal(
        plaintext: Data,
        recipientPublicKey: Data,
    ) throws -> (
        ephemeralPublicKey: Data,
        nonce: Data,
        ciphertext: Data,
    ) {
        let recipientKey = Array(recipientPublicKey)
        guard recipientKey.count == sodium.box.PublicKeyBytes else {
            throw CryptoBoxError.invalidRecipientPublicKey
        }

        guard let ephemeralKeyPair = sodium.box.keyPair() else {
            throw CryptoBoxError.randomGenerationFailed
        }

        guard let sealed = sodium.box.seal(
            message: Array(plaintext),
            recipientPublicKey: recipientKey,
            senderSecretKey: ephemeralKeyPair.secretKey,
        ) as (authenticatedCipherText: Bytes, nonce: Box.Nonce)? else {
            throw CryptoBoxError.randomGenerationFailed
        }

        return (
            ephemeralPublicKey: Data(ephemeralKeyPair.publicKey),
            nonce: Data(sealed.nonce),
            ciphertext: Data(sealed.authenticatedCipherText),
        )
    }

    private static func deriveSecretBoxKey(from sharedSecret: Data) throws -> Bytes {
        guard sharedSecret.count == Int(crypto_core_hsalsa20_keybytes()) else {
            throw CryptoBoxError.invalidCiphertext
        }

        var derivedKey = Bytes(repeating: 0, count: Int(crypto_core_hsalsa20_outputbytes()))
        var zeroInput = Bytes(repeating: 0, count: Int(crypto_core_hsalsa20_inputbytes()))
        var sharedSecretBytes = Array(sharedSecret)
        var constant = hsalsa20Constant

        guard crypto_core_hsalsa20(
            &derivedKey,
            &zeroInput,
            &sharedSecretBytes,
            &constant,
        ) == 0 else {
            throw CryptoBoxError.authenticationFailed
        }

        return derivedKey
    }
}
