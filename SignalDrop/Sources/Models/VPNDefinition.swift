import Foundation

enum VPNExecutionTier: Sendable, Equatable {
    case nonElevated
    case elevated
}

enum VPNConnectionStatus: Sendable, Equatable {
    case connected
    case disconnected
    case connecting
    case unknown
}

struct VPNDefinition: Sendable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let cliPaths: [String]
    let statusArgv: [String]
    let connectArgv: [String]
    let disconnectArgv: [String]
    let executionTier: VPNExecutionTier
    let parseStatus: @Sendable (String, Int32) -> VPNConnectionStatus

    static func == (lhs: VPNDefinition, rhs: VPNDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

struct VPNState: Sendable, Identifiable, Equatable {
    let id: String
    let definition: VPNDefinition
    var status: VPNConnectionStatus
    var detectedCLIPath: String?
    var isEnabled: Bool

    var isCLIInstalled: Bool { detectedCLIPath != nil }
}

extension VPNDefinition {
    static let tailscale = VPNDefinition(
        id: "tailscale",
        displayName: "Tailscale",
        cliPaths: [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale"
        ],
        statusArgv: ["status", "--json"],
        connectArgv: ["up"],
        disconnectArgv: ["down"],
        executionTier: .nonElevated,
        parseStatus: { output, exitCode in
            guard exitCode == 0 else { return .disconnected }
            if output.contains("\"BackendState\":\"Running\"") { return .connected }
            if output.contains("\"BackendState\":\"Starting\"") { return .connecting }
            return .disconnected
        }
    )

    static let pia = VPNDefinition(
        id: "pia",
        displayName: "Private Internet Access",
        cliPaths: [
            "/Applications/Private Internet Access.app/Contents/MacOS/piactl",
            "/usr/local/bin/piactl",
            "/opt/homebrew/bin/piactl"
        ],
        statusArgv: ["get", "connectionstate"],
        connectArgv: ["connect"],
        disconnectArgv: ["disconnect"],
        executionTier: .nonElevated,
        parseStatus: { output, _ in
            switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "Connected": return .connected
            case "Connecting": return .connecting
            case "Disconnected", "Disconnecting": return .disconnected
            default: return .unknown
            }
        }
    )

    static let wireGuard = VPNDefinition(
        id: "wireguard",
        displayName: "WireGuard",
        cliPaths: [
            "/usr/local/bin/wg-quick",
            "/opt/homebrew/bin/wg-quick"
        ],
        statusArgv: [],
        connectArgv: ["up", "wg0"],
        disconnectArgv: ["down", "wg0"],
        executionTier: .elevated,
        parseStatus: { output, exitCode in
            exitCode == 0 && !output.isEmpty ? .connected : .disconnected
        }
    )

    static let allCurated: [VPNDefinition] = [.tailscale, .pia, .wireGuard]
}
