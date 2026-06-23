import SwiftUI
import Sparkle

struct UpdateSettingsView: View {
    let updaterController: SPUStandardUpdaterController

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (build \(build))"
    }

    var body: some View {
        Form {
            Toggle(
                String(localized: "Automatically check for updates"),
                isOn: Binding(
                    get: { updaterController.updater.automaticallyChecksForUpdates },
                    set: { updaterController.updater.automaticallyChecksForUpdates = $0 }
                )
            )
            .accessibilityLabel(String(localized: "Automatically check for updates in the background"))

            Button(String(localized: "Check for Updates Now")) {
                updaterController.checkForUpdates(nil)
            }
            .accessibilityLabel(String(localized: "Check for updates now"))

            Text(versionString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "Current version: \(versionString)"))
        }
        .padding()
    }
}
