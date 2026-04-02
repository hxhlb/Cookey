import Foundation

struct DeepLink: Equatable {
    enum RequestType: String, Equatable {
        case login
        case refresh
    }

    let rid: String
    let serverURL: URL
    let targetURL: URL
    let recipientPublicKeyBase64: String
    let deviceID: String
    let requestType: RequestType
    let expiresAt: Date?
    let requestProof: String?
    let requestSecret: String?

    init(
        rid: String,
        serverURL: URL,
        targetURL: URL,
        recipientPublicKeyBase64: String,
        deviceID: String,
        requestType: RequestType,
        expiresAt: Date? = nil,
        requestProof: String? = nil,
        requestSecret: String? = nil
    ) {
        self.rid = rid
        self.serverURL = serverURL
        self.targetURL = targetURL
        self.recipientPublicKeyBase64 = recipientPublicKeyBase64
        self.deviceID = deviceID
        self.requestType = requestType
        self.expiresAt = expiresAt
        self.requestProof = requestProof
        self.requestSecret = requestSecret
    }

    init?(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "cookey",
            components.host?.lowercased() == "login"
        else {
            return nil
        }

        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let value = item.value else { continue }
            values[item.name] = value.removingPercentEncoding ?? value
        }

        guard
            let rid = values["rid"], !rid.isEmpty,
            let serverValue = values["server"], let serverURL = URL(string: serverValue),
            let targetValue = values["target"], let targetURL = URL(string: targetValue),
            let publicKey = values["pubkey"], !publicKey.isEmpty,
            let deviceID = values["device_id"], !deviceID.isEmpty
        else {
            return nil
        }

        guard
            Self.isAllowedRelayURL(serverURL),
            Self.isAllowedTargetURL(targetURL)
        else {
            return nil
        }

        self.rid = rid
        self.serverURL = serverURL
        self.targetURL = targetURL
        recipientPublicKeyBase64 = publicKey
        self.deviceID = deviceID
        requestType = RequestType(rawValue: values["request_type"]?.lowercased() ?? "") ?? .login
        expiresAt = ISO8601DateFormatter().date(from: values["expires_at"] ?? "")
        requestProof = values["request_proof"]
        requestSecret = values["request_secret"]
    }

    static func isAllowedRelayURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        switch scheme {
        case "https":
            return url.host?.isEmpty == false
        case "http":
            guard let host = url.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
        default:
            return false
        }
    }

    static func isAllowedTargetURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        switch scheme {
        case "https":
            return url.host?.isEmpty == false
        case "http":
            guard let host = url.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
        default:
            return false
        }
    }
}
