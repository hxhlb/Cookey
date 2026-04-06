import Foundation

// MARK: - Verification State

enum KeyVerificationState: Equatable {
    case trusted(fingerprint: String)
    case keyChanged(oldFingerprint: String, newFingerprint: String)
    case knownKeyNewDevice(fingerprint: String)
    case firstTime(fingerprint: String)
}

// MARK: - Model

struct TrustedKey: Codable, Equatable {
    let deviceID: String
    let publicKeyBase64: String
    let fingerprint: String
    let firstTrustedAt: Date
    var lastSeenAt: Date
    var label: String?
}

// MARK: - Store

enum TrustedKeyStore {
    // MARK: Public

    static func verify(deviceID: String, publicKeyBase64: String) -> KeyVerificationState {
        let fingerprint = (try? KeyFingerprint.compute(fromX25519PublicKeyBase64: publicKeyBase64)) ?? publicKeyBase64
        let entries = load()

        if let existing = entries.first(where: { $0.deviceID == deviceID }) {
            if existing.publicKeyBase64 == publicKeyBase64 {
                touchLastSeen(deviceID: deviceID)
                return .trusted(fingerprint: fingerprint)
            }
            return .keyChanged(oldFingerprint: existing.fingerprint, newFingerprint: fingerprint)
        }

        if entries.contains(where: { $0.publicKeyBase64 == publicKeyBase64 }) {
            return .knownKeyNewDevice(fingerprint: fingerprint)
        }

        return .firstTime(fingerprint: fingerprint)
    }

    static func trust(deviceID: String, publicKeyBase64: String, fingerprint: String) {
        var entries = load()
        let now = Date()

        if let index = entries.firstIndex(where: { $0.deviceID == deviceID }) {
            var entry = entries[index]
            entry = TrustedKey(
                deviceID: deviceID,
                publicKeyBase64: publicKeyBase64,
                fingerprint: fingerprint,
                firstTrustedAt: entry.firstTrustedAt,
                lastSeenAt: now,
                label: entry.label
            )
            entries[index] = entry
        } else {
            entries.append(TrustedKey(
                deviceID: deviceID,
                publicKeyBase64: publicKeyBase64,
                fingerprint: fingerprint,
                firstTrustedAt: now,
                lastSeenAt: now,
                label: nil
            ))
        }

        save(entries)
    }

    static func remove(deviceID: String) {
        var entries = load()
        entries.removeAll { $0.deviceID == deviceID }
        save(entries)
    }

    static func allTrusted() -> [TrustedKey] {
        load()
    }

    static func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        var entries = load()
        guard sourceIndex >= 0, sourceIndex < entries.count,
              destinationIndex >= 0, destinationIndex < entries.count
        else { return }
        let item = entries.remove(at: sourceIndex)
        entries.insert(item, at: destinationIndex)
        save(entries)
    }

    private static func touchLastSeen(deviceID: String) {
        var entries = load()
        guard let index = entries.firstIndex(where: { $0.deviceID == deviceID }) else { return }
        entries[index].lastSeenAt = Date()
        save(entries)
    }

    // MARK: Private

    private static let lock = NSLock()

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("wiki.qaq.cookey.app", isDirectory: true)
        return directory.appendingPathComponent("trusted_clis.json")
    }

    private static func load() -> [TrustedKey] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: storageURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TrustedKey].self, from: data)) ?? []
    }

    private static func save(_ entries: [TrustedKey]) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(entries) else { return }

        let fileManager = FileManager.default
        let directory = storageURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700,
            ])
        }

        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")

        do {
            try data.write(to: tempURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
            if fileManager.fileExists(atPath: storageURL.path) {
                _ = try fileManager.replaceItemAt(storageURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: storageURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
        }
    }
}
