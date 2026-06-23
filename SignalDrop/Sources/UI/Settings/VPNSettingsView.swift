import SwiftUI

struct VPNSettingsView: View {
    @ObservedObject var vpnManager: VPNManager
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager

    var body: some View {
        Form {
            if !licenseManager.isPaid {
                paidOverlay
            } else {
                vpnToggles
                warningToggle
                requestButton
            }
        }
        .padding()
    }

    @ViewBuilder
    private var vpnToggles: some View {
        Section {
            Text(String(localized: "Monitored VPNs"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(vpnManager.vpnStates) { vpnState in
                HStack {
                    Toggle(vpnState.definition.displayName, isOn: Binding(
                        get: { settingsStore.enabledVPNs.contains(vpnState.id) },
                        set: { enabled in
                            if enabled {
                                settingsStore.enabledVPNs.insert(vpnState.id)
                            } else {
                                settingsStore.enabledVPNs.remove(vpnState.id)
                            }
                            vpnManager.setEnabled(vpnID: vpnState.id, enabled: enabled)
                        }
                    ))
                    .accessibilityLabel(String(localized: "Monitor \(vpnState.definition.displayName)"))

                    if !vpnState.isCLIInstalled {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .accessibilityLabel(String(localized: "\(vpnState.definition.displayName) CLI not found"))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var warningToggle: some View {
        Section {
            Toggle(String(localized: "Show multi-VPN warning"), isOn: $settingsStore.showMultiVPNWarning)
                .accessibilityLabel(String(localized: "Show warning when multiple VPNs are active"))
        }
    }

    @ViewBuilder
    private var requestButton: some View {
        Section {
            Button {
                if let url = URL(string: "https://github.com/ScottSucksAtProgramming/SignalDrop/issues/new?template=vpn_request.md") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label(String(localized: "Request a VPN"), systemImage: "plus.bubble")
            }
            .accessibilityLabel(String(localized: "Request support for a new VPN provider"))
        }
    }

    @ViewBuilder
    private var paidOverlay: some View {
        VStack(spacing: 12) {
            ForEach(VPNDefinition.allCurated) { def in
                Toggle(def.displayName, isOn: .constant(true))
                    .disabled(true)
            }
            Toggle(String(localized: "Show multi-VPN warning"), isOn: .constant(true))
                .disabled(true)
        }
        .opacity(0.5)
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(String(localized: "VPN settings require a paid license"))
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .accessibilityLabel(String(localized: "VPN settings are a paid feature"))
    }
}
