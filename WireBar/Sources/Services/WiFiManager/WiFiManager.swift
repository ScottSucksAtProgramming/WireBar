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

    private nonisolated(unsafe) let scanner: WiFiScanning

    init(scanner: WiFiScanning = CoreWLANScanner()) {
        self.scanner = scanner
        self.isWiFiPoweredOn = scanner.isPoweredOn()
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
        let ssid = network.ssid
        // associate() blocks for seconds; running it inline froze the popover.
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: Error?
            do {
                try scanner.associateToNetwork(ssid: ssid, password: password)
            } catch {
                failure = error
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
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
