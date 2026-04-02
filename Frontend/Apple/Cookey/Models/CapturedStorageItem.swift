import Foundation

struct CapturedStorageItem: Codable, Equatable {
    let name: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case name
        case value
    }

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        value = (try? container.decodeIfPresent(String.self, forKey: .value)) ?? ""
    }
}
