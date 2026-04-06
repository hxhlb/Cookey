import CryptoKit
import Foundation

enum KeyFingerprintError: Error {
    case invalidPublicKey
}

enum KeyFingerprint {
    /// 256-entry emoji lookup table, indexed by byte value 0x00–0xFF.
    static let emojiTable: [String] = [
        // 0x00–0x0F
        "🍎", "🍊", "🍋", "🍇", "🍉", "🍓", "🫐", "🍒",
        "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑",
        // 0x10–0x1F
        "🥦", "🥬", "🥒", "🌶", "🫑", "🌽", "🥕", "🫒",
        "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🧀",
        // 0x20–0x2F
        "🥚", "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖",
        "🌭", "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆",
        // 0x30–0x3F
        "🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫", "🍝",
        "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
        // 0x40–0x4F
        "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡",
        "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮",
        // 0x50–0x5F
        "🍭", "🍬", "🍫", "🍩", "🍪", "🌰", "🥜", "🫘",
        "🍯", "🥛", "🍼", "🫖", "🍵", "🧃", "🥤", "🧋",
        // 0x60–0x6F
        "🍺", "🍻", "🥂", "🍷", "🫗", "🍸", "🍹", "🧉",
        "🍾", "🧊", "🥄", "🍴", "🥣", "🥡", "🥢", "🧂",
        // 0x70–0x7F
        "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉",
        "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🥍", "🏏",
        // 0x80–0x8F
        "🪃", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊",
        "🥋", "🎽", "🛹", "🛼", "🛷", "⛸", "🥌", "🎿",
        // 0x90–0x9F
        "🎯", "🪀", "🎲", "🧩", "🎰", "🎳", "🎮", "🕹",
        "🎻", "🎸", "🎺", "🎷", "🪗", "🥁", "🪘", "🎹",
        // 0xA0–0xAF
        "🔔", "🎵", "🎶", "🎤", "🎧", "📻", "🎙", "📯",
        "🔕", "🔊", "🔉", "🔈", "📢", "📣", "🔇", "🪈",
        // 0xB0–0xBF
        "🌍", "🌎", "🌏", "🌐", "🧭", "🏔", "⛰", "🌋",
        "🗻", "🏕", "🏖", "🏜", "🏝", "🏞", "🏟", "🏛",
        // 0xC0–0xCF
        "🏗", "🧱", "🪨", "🪵", "🛖", "🏘", "🏚", "🏠",
        "🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩",
        // 0xD0–0xDF
        "🏪", "🏫", "🏬", "🏭", "🏯", "🏰", "💒", "🗼",
        "🗽", "⛪", "🕌", "🛕", "🕍", "⛩", "🕋", "⛲",
        // 0xE0–0xEF
        "🌁", "🌃", "🏙", "🌄", "🌅", "🌆", "🌇", "🌉",
        "🎠", "🛝", "🎡", "🎢", "💈", "🎪", "🚂", "🚃",
        // 0xF0–0xFF
        "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚝",
        "🚞", "🚋", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒",
    ]

    /// Compute a human-readable fingerprint from a base64-encoded X25519 public key.
    ///
    /// Format: `"xxyy:xxyy:xxyy  emoji1 emoji2 emoji3 emoji4 emoji5 emoji6"`
    static func compute(fromX25519PublicKeyBase64 base64String: String) throws -> String {
        guard let keyData = Data(base64Encoded: base64String), keyData.count == 32 else {
            throw KeyFingerprintError.invalidPublicKey
        }

        let hash = SHA256.hash(data: keyData)
        let bytes = Array(hash)

        // Bytes 0–5 → hex formatted as "xxyy:xxyy:xxyy"
        let hex = String(
            format: "%02x%02x:%02x%02x:%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]
        )

        // Bytes 6–11 → 6 emoji from lookup table
        let emojis = (6 ... 11).map { emojiTable[Int(bytes[$0])] }

        return hex + "  " + emojis.joined(separator: " ")
    }

    /// SHA-256 hex digest of all 256 emoji entries joined by newlines.
    static func emojiTableChecksum() -> String {
        let joined = emojiTable.joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
