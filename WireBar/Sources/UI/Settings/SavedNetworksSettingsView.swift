import SwiftUI

struct SavedNetworksSettingsView: View {
    @ObservedObject var wifiManager: WiFiManager

    @State private var newSSID: String = ""
    @State private var newPassword: String = ""
    @State private var editingSSID: String?
    @State private var replacementPassword: String = ""
    @State private var confirmingForgetAll: Bool = false
    @State private var saveFailed: Bool = false

    var body: some View {
        Form {
            Section(String(localized: "How WireBar stores these")) {
                Text(String(localized: "Passwords you save here are kept in your Mac's keychain, the same place Safari keeps the passwords it remembers for you. They stay on this Mac. WireBar never sends them to us or to anyone else."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Anyone who can unlock your Mac can look them up, the same as any other password you've saved. You can remove any of them below at any time."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "macOS keeps its own copy of your Wi-Fi passwords that WireBar isn't allowed to read, which is why WireBar needs its own."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "Saved networks")) {
                if wifiManager.savedNetworkSSIDs.isEmpty {
                    Text(String(localized: "No saved passwords yet."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(wifiManager.savedNetworkSSIDs, id: \.self) { ssid in
                        savedRow(ssid)
                    }

                    Button(role: .destructive) {
                        confirmingForgetAll = true
                    } label: {
                        Text(String(localized: "Forget All"))
                    }
                    .accessibilityLabel(String(localized: "Forget all saved Wi-Fi passwords"))
                    .confirmationDialog(
                        String(localized: "Forget all saved Wi-Fi passwords?"),
                        isPresented: $confirmingForgetAll,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "Forget All"), role: .destructive) {
                            wifiManager.forgetAllPasswords()
                        }
                        Button(String(localized: "Cancel"), role: .cancel) {}
                    } message: {
                        Text(String(localized: "WireBar will ask for the password next time you join these networks. Your Mac's own saved networks are not affected."))
                    }
                }
            }

            Section(String(localized: "Add a network")) {
                TextField(String(localized: "Network name (SSID)"), text: $newSSID)
                    .accessibilityLabel(String(localized: "Network name to save a password for"))

                SecureField(String(localized: "Password"), text: $newPassword)
                    .accessibilityLabel(String(localized: "Password for the network being added"))

                Button(String(localized: "Save")) {
                    saveFailed = !wifiManager.savePassword(newPassword, for: trimmedNewSSID)
                    if !saveFailed {
                        newSSID = ""
                        newPassword = ""
                    }
                }
                .disabled(trimmedNewSSID.isEmpty || newPassword.isEmpty)
                .accessibilityLabel(String(localized: "Save password for this network"))

                if saveFailed {
                    Text(String(localized: "Your Mac's keychain refused to save that. Nothing was stored."))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "Saved Networks"))
    }

    private var trimmedNewSSID: String {
        newSSID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func savedRow(_ ssid: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(ssid)
                    .lineLimit(1)

                Spacer()

                Button(String(localized: "Change Password")) {
                    editingSSID = (editingSSID == ssid) ? nil : ssid
                    replacementPassword = ""
                    saveFailed = false
                }
                .accessibilityLabel(String(localized: "Change the saved password for \(ssid)"))

                Button(role: .destructive) {
                    wifiManager.forgetPassword(for: ssid)
                    if editingSSID == ssid { editingSSID = nil }
                } label: {
                    Text(String(localized: "Forget"))
                }
                .accessibilityLabel(String(localized: "Forget the saved password for \(ssid)"))
            }

            if editingSSID == ssid {
                // Replace only. WireBar never displays a stored password, so a
                // saved password cannot be read off the screen.
                HStack {
                    SecureField(String(localized: "New password"), text: $replacementPassword)
                        .accessibilityLabel(String(localized: "New password for \(ssid)"))

                    Button(String(localized: "Save")) {
                        saveFailed = !wifiManager.savePassword(replacementPassword, for: ssid)
                        if !saveFailed {
                            editingSSID = nil
                            replacementPassword = ""
                        }
                    }
                    .disabled(replacementPassword.isEmpty)

                    Button(String(localized: "Cancel")) {
                        editingSSID = nil
                        replacementPassword = ""
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
