import SwiftUI

struct NetworkDetailsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager

    private var isLocked: Bool { !licenseManager.isPaid }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Network name (SSID)"), isOn: $settingsStore.showNetworkName)
                    .accessibilityLabel(String(localized: "Show network name"))
                Toggle(String(localized: "Signal strength"), isOn: $settingsStore.showSignalStrength)
                    .accessibilityLabel(String(localized: "Show signal strength"))
            } header: {
                Text(String(localized: "Basic Details"))
            }

            Section {
                advancedToggle(String(localized: "Band / Frequency"), isOn: $settingsStore.showBand)
                    .accessibilityLabel(String(localized: "Show band and frequency"))
                advancedToggle(String(localized: "Channel"), isOn: $settingsStore.showChannel)
                    .accessibilityLabel(String(localized: "Show channel number"))
                advancedToggle(String(localized: "Link speed"), isOn: $settingsStore.showLinkSpeed)
                    .accessibilityLabel(String(localized: "Show link speed"))
                advancedToggle(String(localized: "BSSID"), isOn: $settingsStore.showBSSID)
                    .accessibilityLabel(String(localized: "Show BSSID"))
                advancedToggle(String(localized: "DNS servers"), isOn: $settingsStore.showDNS)
                    .accessibilityLabel(String(localized: "Show DNS servers"))
                advancedToggle(String(localized: "Gateway"), isOn: $settingsStore.showGateway)
                    .accessibilityLabel(String(localized: "Show gateway address"))
                advancedToggle(String(localized: "Subnet mask"), isOn: $settingsStore.showSubnet)
                    .accessibilityLabel(String(localized: "Show subnet mask"))
            } header: {
                HStack {
                    Text(String(localized: "Advanced Details"))
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(String(localized: "Requires paid upgrade"))
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func advancedToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .disabled(isLocked)
    }
}
