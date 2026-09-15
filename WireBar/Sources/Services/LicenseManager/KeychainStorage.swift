import Foundation
import Security

// MARK: - Protocol

protocol KeychainStoring: Sendable {
    func save(key: String, value: String) -> Bool
    func load(key: String) -> String?
    func delete(key: String) -> Bool
    func saveDate(key: String, value: Date) -> Bool
    func loadDate(key: String) -> Date?
}

// MARK: - Real Keychain implementation

struct KeychainStorage: KeychainStoring, Sendable {
    private let service: String
    private let useDataProtection: Bool

    /// `useDataProtection` opts into the modern (iOS-style) keychain, where items are
    /// bound to this app's code signature and `kSecAttrAccessible` is honoured. It is
    /// off by default: the license item predates this and lives in the file-based
    /// keychain, and switching it would orphan already-stored licenses.
    init(service: String = LicenseConfig.keychainServiceName, useDataProtection: Bool = false) {
        self.service = service
        self.useDataProtection = useDataProtection
    }

    private func baseQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if useDataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
            // Never sync secrets to iCloud.
            query[kSecAttrSynchronizable as String] = false
        }
        return query
    }

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key)

        var query = baseQuery(key: key)
        query[kSecValueData as String] = data
        if useDataProtection {
            // Unreadable while the device is locked, and never restored to another Mac.
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func load(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    @discardableResult
    func delete(key: String) -> Bool {
        return SecItemDelete(baseQuery(key: key) as CFDictionary) == errSecSuccess
    }

    func saveDate(key: String, value: Date) -> Bool {
        let timestamp = String(value.timeIntervalSince1970)
        return save(key: key, value: timestamp)
    }

    func loadDate(key: String) -> Date? {
        guard let string = load(key: key),
              let interval = TimeInterval(string)
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}

// MARK: - In-memory implementation for tests

final class InMemoryKeychainStorage: KeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]

    func save(key: String, value: String) -> Bool {
        store[key] = value
        return true
    }

    func load(key: String) -> String? {
        store[key]
    }

    func delete(key: String) -> Bool {
        store.removeValue(forKey: key) != nil
    }

    func saveDate(key: String, value: Date) -> Bool {
        store[key] = String(value.timeIntervalSince1970)
        return true
    }

    func loadDate(key: String) -> Date? {
        guard let string = store[key], let interval = TimeInterval(string) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
