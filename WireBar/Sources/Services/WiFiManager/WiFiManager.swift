import Foundation
import CoreWLAN
import Combine

final class WiFiManager: ObservableObject, @unchecked Sendable {
    @Published private(set) var networks: [ScannedNetwork] = []
    @Published private(set) var isWiFiPoweredOn: Bool = true
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanError: Error?
    @Published private(set) var joinError: Error?
    @Published private(set) var isJoining: Bool = false
    /// SSIDs WireBar has a password stored for. Never holds the passwords themselves.
    @Published private(set) var savedNetworkSSIDs: [String] = []

    private nonisolated(unsafe) let scanner: WiFiScanning
    private nonisolated(unsafe) let keychain: KeychainStoring

    /// Separate from the license item so Wi-Fi passwords are their own keychain service.
    static let keychainService = "com.scottkostolni.WireBar.wifi"

    init(
        scanner: WiFiScanning = CoreWLANScanner(),
        keychain: KeychainStoring = KeychainStorage(service: WiFiManager.keychainService)
    ) {
        self.scanner = scanner
        self.keychain = keychain
        self.isWiFiPoweredOn = scanner.isPoweredOn()
        self.savedNetworkSSIDs = keychain.allKeys()
    }

    // MARK: - Saved credentials

    /// One keychain item per network. Encoded as JSON so an 802.1X username can ride
    /// along with the password without a second keychain service, which would put
    /// usernames into allKeys() and so into the saved-networks list.
    private struct StoredCredentials: Codable {
        var username: String?
        var password: String
    }

    private func loadCredentials(for ssid: String) -> StoredCredentials? {
        guard let raw = keychain.load(key: ssid) else { return nil }
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(StoredCredentials.self, from: data) {
            return decoded
        }
        // Entries written before usernames existed are the bare password.
        return StoredCredentials(username: nil, password: raw)
    }

    private func encode(_ credentials: StoredCredentials) -> String? {
        guard let data = try? JSONEncoder().encode(credentials) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// The 802.1X username stored for `ssid`, if any. Usernames are not secret in the
    /// way passwords are, so the UI may show this to save the user retyping it.
    func savedUsername(for ssid: String) -> String? {
        loadCredentials(for: ssid)?.username
    }

    // MARK: - Saved passwords

    /// Stores or replaces the password for `ssid`. Returns false if the keychain
    /// refused the write, which the caller must surface: `save` deletes before it
    /// adds, so a rejected write leaves nothing behind.
    @discardableResult
    func savePassword(_ password: String, username: String?, for ssid: String) -> Bool {
        guard let encoded = encode(StoredCredentials(username: username, password: password)) else {
            return false
        }
        let saved = keychain.save(key: ssid, value: encoded)
        savedNetworkSSIDs = keychain.allKeys()
        return saved
    }

    func hasSavedPassword(for ssid: String) -> Bool {
        keychain.load(key: ssid) != nil
    }

    func forgetPassword(for ssid: String) {
        keychain.delete(key: ssid)
        savedNetworkSSIDs = keychain.allKeys()
    }

    func forgetAllPasswords() {
        for ssid in keychain.allKeys() {
            keychain.delete(key: ssid)
        }
        savedNetworkSSIDs = keychain.allKeys()
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil

        let scanner = self.scanner
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.performScan(scanner: scanner)
            DispatchQueue.main.async { [weak self] in
                switch result {
                case .success(let sorted):
                    self?.networks = sorted
                case .failure(let error):
                    self?.scanError = error
                    self?.networks = []
                }
                self?.isScanning = false
            }
        }
    }

    private static func performScan(scanner: WiFiScanning) -> Result<[ScannedNetwork], Error> {
        do {
            var scanned = try scanner.scanForNetworks()
            let currentSSID = scanner.currentSSID()

            scanned = scanned.map { network in
                var n = network
                n.isCurrent = (network.ssid == currentSSID)
                return n
            }

            scanned = dedupeBySSID(scanned)

            let known = scanned.filter(\.isKnown).sorted { $0.rssi > $1.rssi }
            let other = scanned.filter { !$0.isKnown }.sorted { $0.rssi > $1.rssi }
            return .success(known + other)
        } catch {
            return .failure(error)
        }
    }

    /// A scan returns one entry per access point radio, so a network served by
    /// several APs appears several times. The user picks a network, not a radio —
    /// keep only the strongest entry for each SSID.
    private static func dedupeBySSID(_ networks: [ScannedNetwork]) -> [ScannedNetwork] {
        var strongest: [String: ScannedNetwork] = [:]
        for network in networks {
            if let existing = strongest[network.ssid], existing.rssi >= network.rssi {
                continue
            }
            strongest[network.ssid] = network
        }
        return Array(strongest.values)
    }

    func joinNetwork(_ network: ScannedNetwork, password: String?, username: String? = nil) {
        joinError = nil
        isJoining = true

        let scanner = self.scanner
        let ssid = network.ssid
        let isEnterprise = network.securityType.isEnterprise
        // macOS keeps saved Wi-Fi passwords in the root-owned System keychain, which
        // third-party apps cannot read, so remember what the user typed ourselves.
        let stored = loadCredentials(for: ssid)
        let effectivePassword = password ?? stored?.password
        let effectiveUsername = username ?? stored?.username

        // associate() blocks for seconds; running it inline froze the popover.
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: Error?
            do {
                if isEnterprise {
                    guard let effectiveUsername, let effectivePassword else {
                        throw NSError(
                            domain: "WiFiManager",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "\(ssid) needs a username and password.")]
                        )
                    }
                    try scanner.associateToEnterpriseNetwork(
                        ssid: ssid,
                        username: effectiveUsername,
                        password: effectivePassword
                    )
                } else {
                    try scanner.associateToNetwork(ssid: ssid, password: effectivePassword)
                }
            } catch {
                failure = error
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Only remember credentials the user actually typed, and only once they
                // worked. A failure is not evidence the stored ones are wrong -- out of
                // range, AP down and timeouts all land here too -- so nothing is
                // discarded; the next successful join overwrites them.
                // Either credential being newly typed is worth persisting: a user
                // correcting only the username must not have that correction dropped
                // because the password came from storage.
                if failure == nil, password != nil || username != nil,
                   let passwordToStore = effectivePassword {
                    self.savePassword(passwordToStore, username: effectiveUsername, for: ssid)
                }
                self.joinError = failure
                self.isJoining = false
                // Rescan on failure too: a failed association still tears down the
                // previous connection, so the old row must stop claiming to be current.
                self.scan()
            }
        }
    }

    func togglePower() {
        let newState = !isWiFiPoweredOn
        do {
            try scanner.setPower(newState)
            isWiFiPoweredOn = newState
        } catch {
            // Power toggle failed — state unchanged
        }
    }
}
