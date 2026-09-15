import SwiftUI

struct NetworkListView: View {
    @ObservedObject var wifiManager: WiFiManager
    @State private var networkAwaitingPassword: ScannedNetwork?
    @State private var showJoinError: Bool = false
    @State private var lastAttemptedNetwork: ScannedNetwork?
    @State private var lastAttemptUsedStoredPassword: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "Wi-Fi Networks"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if wifiManager.isScanning || wifiManager.isJoining {
                    ProgressView()
                        .scaleEffect(0.6)
                        .accessibilityLabel(wifiManager.isJoining
                            ? String(localized: "Joining network")
                            : String(localized: "Scanning for networks"))
                } else {
                    Button {
                        wifiManager.scan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "Refresh network list"))
                }
            }

            if let error = wifiManager.scanError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(String(localized: "Scan error: \(error.localizedDescription)"))
            }

            if wifiManager.networks.isEmpty && !wifiManager.isScanning {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "No networks found"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Location Services may be required to scan."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(wifiManager.networks) { network in
                        networkRow(network)
                        if network.id != wifiManager.networks.last?.id {
                            Divider().padding(.leading, 24)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            if let network = networkAwaitingPassword {
                PasswordInputView(
                    networkName: network.ssid,
                    isEnterprise: network.securityType.isEnterprise,
                    initialUsername: wifiManager.savedUsername(for: network.ssid),
                    onJoin: { username, password in
                        lastAttemptedNetwork = network
                        lastAttemptUsedStoredPassword = false
                        wifiManager.joinNetwork(network, password: password, username: username)
                        networkAwaitingPassword = nil
                    },
                    onCancel: {
                        networkAwaitingPassword = nil
                    }
                )
            }

            if showJoinError, let error = wifiManager.joinError {
                // Wraps and stays selectable: association errors carry the only
                // diagnostic detail the user ever sees, so never truncate them.
                Text(String(localized: "Failed to join: \(error.localizedDescription)"))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityLabel(String(localized: "Failed to join: \(error.localizedDescription)"))
            }
        }
        .onChange(of: wifiManager.isJoining) { isJoining in
            guard !isJoining else { return }
            guard wifiManager.joinError != nil else {
                showJoinError = false
                return
            }
            if lastAttemptUsedStoredPassword, let network = lastAttemptedNetwork {
                // The saved password didn't get us on. Ask for it instead of
                // leaving the user disconnected with only an error.
                lastAttemptUsedStoredPassword = false
                showJoinError = false
                networkAwaitingPassword = network
            } else {
                showJoinError = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Available Wi-Fi networks"))
    }

    @ViewBuilder
    private func networkRow(_ network: ScannedNetwork) -> some View {
        Button {
            handleNetworkTap(network)
        } label: {
            HStack(spacing: 8) {
                signalIcon(for: network)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(network.ssid)
                        .font(.caption)
                        .fontWeight(network.isCurrent ? .semibold : .regular)
                        .lineLimit(1)

                    if network.isKnown {
                        Text(String(localized: "Known Network"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if network.securityType.isSecured {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(network.securityType.displayName)
                }

                Text(network.securityType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if network.isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .accessibilityLabel(String(localized: "Currently connected"))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(networkAccessibilityLabel(for: network))
        .accessibilityHint(network.isCurrent ? "" : String(localized: "Double-tap to join"))
    }

    @ViewBuilder
    private func signalIcon(for network: ScannedNetwork) -> some View {
        let quality = network.signalQuality
        HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(miniBarColor(for: index, quality: quality))
                    .frame(width: 2, height: CGFloat(3 + index * 2))
            }
        }
    }

    private func miniBarColor(for index: Int, quality: SignalQuality) -> Color {
        let filledBars: Int = switch quality {
        case .excellent: 4
        case .good: 3
        case .fair: 2
        case .poor: 1
        }
        return index < filledBars ? .primary : .secondary.opacity(0.3)
    }

    private func networkAccessibilityLabel(for network: ScannedNetwork) -> String {
        var parts = [network.ssid]
        parts.append(String(localized: "Signal \(network.signalQuality.accessibilityName)"))
        parts.append(network.securityType.displayName)
        if network.isKnown { parts.append(String(localized: "Known network")) }
        if network.isCurrent { parts.append(String(localized: "Currently connected")) }
        return parts.joined(separator: ", ")
    }

    private func handleNetworkTap(_ network: ScannedNetwork) {
        guard !network.isCurrent else { return }

        lastAttemptedNetwork = network
        // A "known" profile does not guarantee macOS will hand us the stored PSK.
        // Try without one, but remember that we did, so a failure can fall back to
        // asking rather than just stranding the user offline.
        lastAttemptUsedStoredPassword = network.isKnown && network.securityType.isSecured

        // 802.1X cannot be attempted without a username, so go straight to the
        // prompt unless WireBar already has one stored.
        if network.securityType.isEnterprise,
           wifiManager.savedUsername(for: network.ssid) == nil {
            networkAwaitingPassword = network
            return
        }

        if network.isKnown || !network.securityType.isSecured {
            wifiManager.joinNetwork(network, password: nil)
        } else {
            networkAwaitingPassword = network
        }
    }
}

extension SignalQuality {
    var accessibilityName: String {
        switch self {
        case .excellent: return String(localized: "excellent")
        case .good: return String(localized: "good")
        case .fair: return String(localized: "fair")
        case .poor: return String(localized: "poor")
        }
    }
}
