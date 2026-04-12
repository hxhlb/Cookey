import Foundation
import Security
import Sodium

enum DeviceKeyManager {
    static let service = "wiki.qaq.cookey.device-x25519"

    enum Error: Swift.Error {
        case generationFailed
        case keychain(OSStatus)
    }

    struct KeyPair: Equatable {
        let publicKey: Data
        let secretKey: Data
    }

    static func loadOrCreateKeyPair() throws -> KeyPair {
        let storedPublicKey = try read(account: "public")
        let storedSecretKey = try read(account: "secret")

        if let storedPublicKey, let storedSecretKey {
            guard storedPublicKey.count == Sodium().box.PublicKeyBytes, storedSecretKey.count == Sodium().box.SecretKeyBytes else {
                try removeAll()
                return try loadOrCreateKeyPair()
            }
            return KeyPair(publicKey: storedPublicKey, secretKey: storedSecretKey)
        }

        if storedPublicKey != nil || storedSecretKey != nil {
            try removeAll()
        }

        guard let generated = Sodium().box.keyPair() else {
            throw Error.generationFailed
        }

        let pair = KeyPair(
            publicKey: Data(generated.publicKey),
            secretKey: Data(generated.secretKey),
        )

        try store(pair.publicKey, account: "public")
        try store(pair.secretKey, account: "secret")
        return pair
    }

    static func publicKeyBase64() throws -> String {
        try loadOrCreateKeyPair().publicKey.base64EncodedString()
    }

    static func publicKey() throws -> Data {
        try loadOrCreateKeyPair().publicKey
    }

    static func secretKey() throws -> Data {
        try loadOrCreateKeyPair().secretKey
    }

    static func removeAll() throws {
        try delete(account: "public")
        try delete(account: "secret")
    }

    private static func read(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw Error.keychain(status)
        }
    }

    private static func store(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        guard addStatus == errSecDuplicateItem else {
            throw Error.keychain(addStatus)
        }

        let attributesToUpdate = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributesToUpdate as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw Error.keychain(updateStatus)
        }
    }

    private static func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.keychain(status)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
