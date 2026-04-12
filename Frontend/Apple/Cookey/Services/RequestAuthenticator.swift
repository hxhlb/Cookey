import CryptoKit
import Foundation

enum RequestAuthenticator {
    enum Error: LocalizedError {
        case invalidRequestSecret
        case invalidRequestProof
        case invalidSessionProof
        case missingAuthenticatedFields

        var errorDescription: String? {
            switch self {
            case .invalidRequestSecret:
                "Invalid request secret."
            case .invalidRequestProof:
                "The request could not be authenticated."
            case .invalidSessionProof:
                "The uploaded session proof was invalid."
            case .missingAuthenticatedFields:
                "The request is missing authenticated fields."
            }
        }
    }

    static func verify(_ deepLink: DeepLink) throws {
        guard
            let requestSecret = deepLink.requestSecret,
            let providedRequestProof = deepLink.requestProof,
            let expiresAt = deepLink.expiresAt
        else {
            throw Error.missingAuthenticatedFields
        }

        let expected = try Self.requestProof(
            rid: deepLink.rid,
            serverURL: deepLink.serverURL,
            targetURL: deepLink.targetURL,
            recipientPublicKeyBase64: deepLink.recipientPublicKeyBase64,
            deviceID: deepLink.deviceID,
            requestType: deepLink.requestType,
            expiresAt: expiresAt,
            requestSecret: requestSecret,
        )

        guard expected == providedRequestProof else {
            throw Error.invalidRequestProof
        }
    }

    static func requestProof(
        rid: String,
        serverURL: URL,
        targetURL: URL,
        recipientPublicKeyBase64: String,
        deviceID: String,
        requestType: DeepLink.RequestType,
        expiresAt: Date,
        requestSecret: String,
    ) throws -> String {
        try authenticate(
            purpose: "cookey-request-v1",
            secret: requestSecret,
            fields: [
                rid,
                serverURL.absoluteString,
                targetURL.absoluteString,
                recipientPublicKeyBase64,
                deviceID,
                requestType.rawValue,
                timestamp(expiresAt),
            ],
        )
    }

    static func envelopeProof(
        rid: String,
        envelope: EncryptedSessionEnvelope,
        requestSecret: String,
    ) throws -> String {
        try authenticate(
            purpose: "cookey-session-v1",
            secret: requestSecret,
            fields: [
                rid,
                envelope.algorithm,
                envelope.ephemeralPublicKey,
                envelope.nonce,
                envelope.ciphertext,
                timestamp(envelope.capturedAt),
                String(envelope.version),
            ],
        )
    }

    private static func authenticate(
        purpose: String,
        secret: String,
        fields: [String],
    ) throws -> String {
        guard let secretData = Data(base64URLEncoded: secret), secretData.count >= 16 else {
            throw Error.invalidRequestSecret
        }

        let message = ([purpose] + fields).joined(separator: "\n")
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: SymmetricKey(data: secretData),
        )
        return Data(mac).base64URLEncodedString()
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        let normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - normalized.count % 4) % 4
        self.init(base64Encoded: normalized + String(repeating: "=", count: padding))
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
