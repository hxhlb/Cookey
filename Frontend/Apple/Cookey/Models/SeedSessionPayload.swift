import Foundation

struct SeedRequestPayload: Codable, Equatable {
    let rid: String
    let serverURL: String
    let targetURL: String
    let cliPublicKey: String
    let deviceID: String
    let requestType: String
    let expiresAt: Date
    let requestProof: String
    let requestSecret: String

    enum CodingKeys: String, CodingKey {
        case rid
        case serverURL = "server_url"
        case targetURL = "target_url"
        case cliPublicKey = "cli_public_key"
        case deviceID = "device_id"
        case requestType = "request_type"
        case expiresAt = "expires_at"
        case requestProof = "request_proof"
        case requestSecret = "request_secret"
    }
}

struct SeedSessionPayload: Codable, Equatable {
    let cookies: [CapturedCookie]
    let origins: [CapturedOrigin]
    let request: SeedRequestPayload?

    enum CodingKeys: String, CodingKey {
        case cookies
        case origins
        case request = "_cookey_request"
    }

    var capturedSession: CapturedSession {
        CapturedSession(cookies: cookies, origins: origins, deviceInfo: nil)
    }
}
