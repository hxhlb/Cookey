import Foundation

struct CapturedOrigin: Codable, Equatable {
    let origin: String
    let localStorage: [CapturedStorageItem]

    enum CodingKeys: String, CodingKey {
        case origin
        case localStorage
    }

    init(origin: String, localStorage: [CapturedStorageItem]) {
        self.origin = origin
        self.localStorage = localStorage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        origin = try container.decode(String.self, forKey: .origin)
        localStorage = try container.decodeIfPresent([CapturedStorageItem].self, forKey: .localStorage) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(localStorage, forKey: .localStorage)
    }
}
