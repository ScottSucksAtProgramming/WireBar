import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager

    var body: some View {
        Form {
            if licenseManager.isPaid {
                Toggle(String(localized: "VPN disconnection alerts"), isOn: $settingsStore.notifyVPNDrop)
                    .accessibilityLabel(String(localized: "Notify when a VPN disconnects"))

                Toggle(String(localized: "Wi-Fi disconnection alerts"), isOn: $settingsStore.notifyWiFiDisconnect)
                    .accessibilityLabel(String(localized: "Notify when Wi-Fi disconnects"))

                Toggle(String(localized: "External IP change alerts"), isOn: $settingsStore.notifyIPChange)
                    .accessibilityLabel(String(localized: "Notify when your external IP address changes"))

                Toggle(String(localized: "Network change alerts"), isOn: $settingsStore.notifyNetworkChange)
                    .accessibilityLabel(String(localized: "Notify when you switch to a different Wi-Fi network"))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(String(localized: "Notifications are a paid feature"))
                        .font(.headline)
                    Text(String(localized: "Upgrade to get alerts for VPN drops, Wi-Fi disconnections, and IP changes."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Notifications require a paid license"))
            }
        }
        .padding()
    }
}
