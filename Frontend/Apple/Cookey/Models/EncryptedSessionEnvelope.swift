import Foundation

struct EncryptedSessionEnvelope: Codable {
    let version: Int
    let algorithm: String
    let ephemeralPublicKey: String
    let nonce: String
    let ciphertext: String
    let capturedAt: Date
    let requestSignature: String?

    enum CodingKeys: String, CodingKey {
        case version
        case algorithm
        case nonce
        case ciphertext
        case ephemeralPublicKey = "ephemeral_public_key"
        case capturedAt = "captured_at"
        case requestSignature = "request_signature"
    }
}
