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

    init(service: String = LicenseConfig.keychainServiceName) {
        self.service = service
    }

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
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
