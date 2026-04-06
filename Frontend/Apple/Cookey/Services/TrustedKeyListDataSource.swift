import Combine
import ConfigurableKit
import Foundation

final class TrustedKeyListItem: ObjectListItem, @unchecked Sendable {
    nonisolated let id: UUID
    let trustedCLI: TrustedKey

    init(_ trustedCLI: TrustedKey) {
        // Derive a stable UUID from the deviceID so items are consistently identified
        id = UUID(uuidString: trustedCLI.deviceID) ?? UUID(namespacedFrom: trustedCLI.deviceID)
        self.trustedCLI = trustedCLI
    }

    nonisolated func matches(query: String) -> Bool {
        let q = query.lowercased()
        return trustedCLI.deviceID.lowercased().contains(q)
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

private extension UUID {
    /// Deterministic UUID from an arbitrary string using a v5-like approach.
    init(namespacedFrom string: String) {
        var bytes = [UInt8](repeating: 0, count: 16)
        let data = Array(string.utf8)
        for (i, byte) in data.enumerated() {
            bytes[i % 16] ^= byte
        }
        // Set version 4 bits so it looks like a valid UUID
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = NSUUID(uuidBytes: bytes) as UUID
    }
}

@MainActor
final class TrustedKeyListDataSource: ObjectListDataSource {
    typealias Item = TrustedKeyListItem

    private let subject = PassthroughSubject<Void, Never>()

    var items: [TrustedKeyListItem] {
        TrustedKeyStore.allTrusted().map { TrustedKeyListItem($0) }
    }

    var dataDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func createItem(from _: UIViewController) async -> TrustedKeyListItem? {
        nil // Trust is established via QR scan flow, not manual creation
    }

    func removeItems(_ ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            TrustedKeyStore.remove(deviceID: item.trustedCLI.deviceID)
        }
        subject.send()
    }

    func moveItem(from _: Int, to _: Int) {}

    func configure(cell: ConfigurableView, for item: TrustedKeyListItem) {
        let cli = item.trustedCLI
        let title = cli.label ?? cli.fingerprint
        let description: String = {
            var parts: [String] = []
            if cli.label != nil {
                parts.append(cli.fingerprint)
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append(String(localized: "Last seen: \(formatter.string(from: cli.lastSeenAt))"))
            return parts.joined(separator: "\n")
        }()

        cell.configure(icon: .init(systemName: "key.fill"))
        cell.configure(title: title)
        cell.configure(description: description)
    }
}
