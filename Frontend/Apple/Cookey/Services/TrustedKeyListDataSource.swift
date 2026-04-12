import CryptoKit
import Foundation

final class TrustedKeyListItem: Hashable, @unchecked Sendable {
    nonisolated let id: UUID
    let trustedCLI: TrustedKey

    init(_ trustedCLI: TrustedKey) {
        let combined = [
            trustedCLI.deviceID,
            trustedCLI.publicKeyBase64,
            trustedCLI.fingerprint,
        ].joined()
        id = UUID(namespacedFrom: combined)
        self.trustedCLI = trustedCLI
    }

    nonisolated func matches(query: String) -> Bool {
        let q = query.lowercased()
        return trustedCLI.deviceID.lowercased().contains(q)
            || trustedCLI.publicKeyBase64.lowercased().contains(q)
            || trustedCLI.fingerprint.lowercased().contains(q)
            || (trustedCLI.label?.lowercased().contains(q) ?? false)
    }

    nonisolated static func == (lhs: TrustedKeyListItem, rhs: TrustedKeyListItem) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TrustedKeyListItem {
    var titleText: String {
        trustedCLI.fingerprint
    }

    var detailText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return String(
            format: String(localized: "Last seen: %@"),
            formatter.string(from: trustedCLI.lastSeenAt),
        )
    }
}

private extension UUID {
    init(namespacedFrom string: String) {
        let digest = SHA256.hash(data: Data(string.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = NSUUID(uuidBytes: bytes) as UUID
    }
}
