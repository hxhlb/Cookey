import Foundation

struct CapturedCookie: Codable, Equatable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expires: Double
    let httpOnly: Bool
    let secure: Bool
    let sameSite: String

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case domain
        case path
        case expires
        case httpOnly
        case secure
        case sameSite
    }

    init(
        name: String,
        value: String,
        domain: String,
        path: String,
        expires: Double,
        httpOnly: Bool,
        secure: Bool,
        sameSite: String
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expires = expires
        self.httpOnly = httpOnly
        self.secure = secure
        self.sameSite = sameSite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeString(forKey: .name)
        value = container.decodeString(forKey: .value)
        domain = container.decodeString(forKey: .domain)
        path = container.decodeString(forKey: .path, default: "/")
        expires = container.decodeDouble(forKey: .expires, default: -1)
        httpOnly = container.decodeBool(forKey: .httpOnly)
        secure = container.decodeBool(forKey: .secure)
        sameSite = container.decodeString(forKey: .sameSite)
    }
}

private extension KeyedDecodingContainer {
    func decodeString(forKey key: Key, default defaultValue: String = "") -> String {
        (try? decodeIfPresent(String.self, forKey: key)) ?? defaultValue
    }

    func decodeBool(forKey key: Key, default defaultValue: Bool = false) -> Bool {
        (try? decodeIfPresent(Bool.self, forKey: key)) ?? defaultValue
    }

    func decodeDouble(forKey key: Key, default defaultValue: Double = 0) -> Double {
        (try? decodeIfPresent(Double.self, forKey: key)) ?? defaultValue
    }
}
