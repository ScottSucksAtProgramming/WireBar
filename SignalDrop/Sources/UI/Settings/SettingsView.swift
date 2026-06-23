import SwiftUI
import Sparkle

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject var vpnManager: VPNManager
    let updaterController: SPUStandardUpdaterController

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore, licenseManager: licenseManager)
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
            NotificationSettingsView(settingsStore: settingsStore, licenseManager: licenseManager)
                .tabItem {
                    Label(String(localized: "Notifications"), systemImage: "bell")
                }
            KeyboardShortcutsSettingsView(settingsStore: settingsStore, licenseManager: licenseManager)
                .tabItem {
                    Label(String(localized: "Shortcuts"), systemImage: "keyboard")
                }
            UpdateSettingsView(updaterController: updaterController)
                .tabItem {
                    Label(String(localized: "Updates"), systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 580, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var licenseManager: LicenseManager

    var body: some View {
        Form {
            Toggle(String(localized: "Launch at login"), isOn: $settingsStore.launchAtLogin)
                .accessibilityLabel(String(localized: "Launch SignalDrop when you log in"))

            Section(String(localized: "Menu Bar Display")) {
                if licenseManager.isPaid {
                    Toggle(String(localized: "Show network name"), isOn: $settingsStore.menuBarShowNetworkName)
                        .accessibilityLabel(String(localized: "Show Wi-Fi network name in menu bar"))
                    Toggle(String(localized: "Show VPN indicator"), isOn: $settingsStore.menuBarShowVPNIndicator)
                        .accessibilityLabel(String(localized: "Show VPN connection indicator in menu bar"))
                    Toggle(String(localized: "Show IP address"), isOn: $settingsStore.menuBarShowIP)
                        .accessibilityLabel(String(localized: "Show local IP address in menu bar"))
                } else {
                    Text(String(localized: "Menu bar customization is a paid feature"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Menu bar customization requires a paid license"))
                }
            }
        }
        .padding()
    }
}
