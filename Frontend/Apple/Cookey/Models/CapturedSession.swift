import Foundation

struct DeviceInfo: Codable, Equatable {
    let deviceID: String
    let apnToken: String
    let apnEnvironment: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case apnEnvironment = "apn_environment"
        case apnToken = "apn_token"
        case publicKey = "public_key"
    }
}

struct CapturedSession: Codable, Equatable {
    let cookies: [CapturedCookie]
    let origins: [CapturedOrigin]
    let deviceInfo: DeviceInfo?

    enum CodingKeys: String, CodingKey {
        case cookies
        case origins
        case deviceInfo = "device_info"
    }

    init(cookies: [CapturedCookie], origins: [CapturedOrigin], deviceInfo: DeviceInfo?) {
        self.cookies = cookies
        self.origins = origins
        self.deviceInfo = deviceInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cookies = try container.decodeIfPresent([CapturedCookie].self, forKey: .cookies) ?? []
        origins = try container.decodeIfPresent([CapturedOrigin].self, forKey: .origins) ?? []
        deviceInfo = try? container.decodeIfPresent(DeviceInfo.self, forKey: .deviceInfo)
    }
}
