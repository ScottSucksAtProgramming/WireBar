import SwiftUI

struct PopoverView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var wifiManager: WiFiManager
    @ObservedObject var settingsStore: SettingsStore
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConnectionInfoView(
                networkMonitor: networkMonitor,
                settingsStore: settingsStore
            )

            if networkMonitor.state.isEthernetConnected {
                Divider()
                EthernetInfoView(networkMonitor: networkMonitor)
            }

            if networkMonitor.state.isWiFiPoweredOn {
                Divider()
                NetworkListView(wifiManager: wifiManager)
            }

            Divider()
            quickActions
        }
        .padding()
        .frame(width: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Network status popover"))
    }

    @ViewBuilder
    private var quickActions: some View {
        HStack {
            wifiToggle

            Spacer()

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gear")
                Text(String(localized: "Settings"))
            }
            .accessibilityLabel(String(localized: "Open settings"))
        }
    }

    @ViewBuilder
    private var wifiToggle: some View {
        Toggle(isOn: Binding(
            get: { wifiManager.isWiFiPoweredOn },
            set: { _ in wifiManager.togglePower() }
        )) {
            Label(String(localized: "Wi-Fi"), systemImage: "wifi")
                .font(.caption)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "Wi-Fi power"))
        .accessibilityValue(wifiManager.isWiFiPoweredOn ? String(localized: "On") : String(localized: "Off"))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontDesign(.monospaced)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
