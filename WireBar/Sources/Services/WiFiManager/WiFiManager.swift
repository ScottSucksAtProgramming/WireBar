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

    // MARK: - Saved passwords

    /// Stores or replaces the password for `ssid`. Returns false if the keychain
    /// refused the write, which the caller must surface: `save` deletes before it
    /// adds, so a rejected write leaves nothing behind.
    @discardableResult
    func savePassword(_ password: String, for ssid: String) -> Bool {
        let saved = keychain.save(key: ssid, value: password)
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

    func joinNetwork(_ network: ScannedNetwork, password: String?) {
        joinError = nil
        isJoining = true

        let scanner = self.scanner
        let keychain = self.keychain
        let ssid = network.ssid
        // macOS keeps saved Wi-Fi passwords in the root-owned System keychain, which
        // third-party apps cannot read, so remember what the user typed ourselves.
        let effectivePassword = password ?? keychain.load(key: ssid)

        // associate() blocks for seconds; running it inline froze the popover.
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: Error?
            do {
                try scanner.associateToNetwork(ssid: ssid, password: effectivePassword)
            } catch {
                failure = error
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Only remember a password the user actually typed, and only once it
                // worked. A failure is not evidence the stored one is wrong -- out of
                // range, AP down and timeouts all land here too -- so nothing is
                // discarded; the next successful join overwrites it.
                if failure == nil, let password {
                    keychain.save(key: ssid, value: password)
                    self.savedNetworkSSIDs = keychain.allKeys()
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
