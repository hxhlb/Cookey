import Foundation

struct PairKeyDeepLink: Equatable {
    let pairKey: String
    let serverURL: URL

    init?(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "cookey",
            let pairKey = components.host,
            !pairKey.isEmpty,
            components.path.isEmpty || components.path == "/",
            let serverHost = components.queryItems?.first(where: { $0.name == "host" })?.value,
            let serverURL = Self.httpsRelayURL(from: serverHost)
        else {
            return nil
        }

        self.pairKey = pairKey
        self.serverURL = serverURL
    }

    static func httpsRelayURL(from hostValue: String) -> URL? {
        let trimmed = hostValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            !trimmed.contains("://"),
            !trimmed.contains("/"),
            !trimmed.contains("?"),
            !trimmed.contains("#"),
            !trimmed.contains("@"),
            var components = URLComponents(string: "https://\(trimmed)"),
            components.scheme?.lowercased() == "https",
            components.user == nil,
            components.password == nil,
            components.host?.isEmpty == false,
            components.query == nil,
            components.fragment == nil,
            components.path.isEmpty || components.path == "/"
        else {
            return nil
        }

        components.path = ""
        return components.url
    }
}

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
        isAllowedURL(url)
    }

    static func isAllowedTargetURL(_ url: URL) -> Bool {
        isAllowedURL(url)
    }

    private static func isAllowedURL(_ url: URL) -> Bool {
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
