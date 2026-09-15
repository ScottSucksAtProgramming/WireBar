import Foundation

protocol WiFiScanning: Sendable {
    func scanForNetworks() throws -> [ScannedNetwork]
    func knownNetworkSSIDs() -> Set<String>
    func associateToNetwork(ssid: String, password: String?) throws
    func setPower(_ on: Bool) throws
    func isPoweredOn() -> Bool
    func currentSSID() -> String?
}
