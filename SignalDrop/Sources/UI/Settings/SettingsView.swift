import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject var vpnManager: VPNManager

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label(String(localized: "General"), systemImage: "gear")
                }
            NetworkDetailsSettingsView(settingsStore: settingsStore, licenseManager: licenseManager)
                .tabItem {
                    Label(String(localized: "Network Details"), systemImage: "network")
                }
            IPPingSettingsView(settingsStore: settingsStore, licenseManager: licenseManager)
                .tabItem {
                    Label(String(localized: "IP & Latency"), systemImage: "globe")
                }
            VPNSettingsView(vpnManager: vpnManager, settingsStore: settingsStore, licenseManager: licenseManager)
                .tabItem {
                    Label(String(localized: "VPN"), systemImage: "shield.lefthalf.filled")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Toggle(String(localized: "Launch at login"), isOn: $settingsStore.launchAtLogin)
                .accessibilityLabel(String(localized: "Launch SignalDrop when you log in"))
        }
        .padding()
    }
}
