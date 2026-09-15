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

    // Deliberately the file-based keychain, not the data-protection one. The modern
    // keychain (kSecUseDataProtectionKeychain) needs an application-identifier or
    // keychain-access-groups entitlement, which only a provisioning profile grants;
    // a Developer ID build has neither, and every SecItemAdd fails with -34018
    // errSecMissingEntitlement. The file-based keychain is still encrypted at rest and
    // ACLs each item to the creating application's code signature.
    init(service: String = LicenseConfig.keychainServiceName) {
        self.service = service
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key)

        var query = baseQuery(key: key)
        query[kSecValueData as String] = data
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
