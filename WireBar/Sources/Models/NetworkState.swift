import Foundation

struct NetworkState: Sendable {
    var isConnected: Bool = false
    var connectionType: ConnectionType = .none

    var ssid: String?
    var signalStrength: Int = 0
    var noiseLevel: Int = 0
    var channelNumber: Int?
    var channelBand: WLANChannelBand?
    var bssid: String?
    var transmitRate: Double = 0

    var localIPAddress: String?
    var isEthernetConnected: Bool = false
    var isWiFiPoweredOn: Bool = true

    var isHotspot: Bool = false

    var ethernetIPAddress: String?
    var gatewayAddress: String?
    var subnetMask: String?
    var dnsServers: [String] = []
    var primaryInterface: String?
    var linkSpeed: Double = 0

    var signalQuality: SignalQuality {
        switch signalStrength {
        case -50...0: return .excellent
        case -60...(-51): return .good
        case -70...(-61): return .fair
        default: return .poor
        }
    }
}

enum ConnectionType: Sendable {
    case none
    case wifi
    case ethernet
    case wifiAndEthernet
}

enum SignalQuality: Sendable {
    case excellent
    case good
    case fair
    case poor

    var localizedDescription: String {
        switch self {
        case .excellent: String(localized: "excellent")
        case .good: String(localized: "good")
        case .fair: String(localized: "fair")
        case .poor: String(localized: "poor")
        }
    }
}

enum SignalDisplayFormat: Int, Sendable {
    case bars = 0
    case percentage = 1
    case dBm = 2
}
