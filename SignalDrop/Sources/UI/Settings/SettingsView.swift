import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(String(localized: "General"), systemImage: "gear")
                }
        }
        .frame(width: 400, height: 250)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = true

    var body: some View {
        Form {
            Toggle(String(localized: "Launch at login"), isOn: $launchAtLogin)
                .accessibilityLabel(String(localized: "Launch SignalDrop when you log in"))
        }
        .padding()
    }
}
