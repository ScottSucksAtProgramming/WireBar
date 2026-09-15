import SwiftUI

struct SavedNetworksSettingsView: View {
    @ObservedObject var wifiManager: WiFiManager

    @State private var newSSID: String = ""
    @State private var newUsername: String = ""
    @State private var newPassword: String = ""
    @State private var editingSSID: String?
    @State private var replacementPassword: String = ""
    @State private var confirmingForgetAll: Bool = false
    @State private var saveFailed: Bool = false

    var body: some View {
        Form {
            Section {
                Text(String(localized: "If you switch networks often, WireBar can store passwords locally. If you choose not to store your passwords with WireBar you will need to enter the network password each time you switch to it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "These passwords are used only to connect to Wi-Fi networks and are never sent to the cloud, to developers, or to anyone else."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "You can remove these passwords at any time."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "About Storing Passwords in WireBar")) {
                Text(String(localized: "Your Mac already stores Wi-Fi passwords which it uses to automatically connect to networks. WireBar cannot access these passwords."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Passwords stored by WireBar are stored locally, in your User Keychain, the same place Safari stores passwords it remembers for you. Anyone who can unlock your user account is able to access and read these passwords."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Consider how comfortable you are with that before saving passwords in WireBar."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(String(localized: "Enterprise Networks")) {
                Text(String(localized: "Work and school networks sign you in with an account instead of a shared password. For those, WireBar keeps the username and password you enter, in the same place and the same way."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "These accounts are often used to access multiple systems. Review your network's security policies before storing the password in WireBar."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: "Network name to save a password for"))

                TextField(String(localized: "Username (work or school networks only)"), text: $newUsername)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: "Username, only needed for work or school networks"))

                SecureField(String(localized: "Password"), text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: "Password for the network being added"))

                Button(String(localized: "Save")) {
                    saveFailed = !wifiManager.savePassword(
                        newPassword,
                        username: trimmedNewUsername.isEmpty ? nil : trimmedNewUsername,
                        for: trimmedNewSSID
                    )
                    if !saveFailed {
                        newSSID = ""
                        newUsername = ""
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
    }

    private var trimmedNewSSID: String {
        newSSID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewUsername: String {
        newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func savedRow(_ ssid: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(ssid)
                        .lineLimit(1)

                    if let username = wifiManager.savedUsername(for: ssid) {
                        Text(username)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

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
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(String(localized: "New password for \(ssid)"))

                    Button(String(localized: "Save")) {
                        saveFailed = !wifiManager.savePassword(
                            replacementPassword,
                            username: wifiManager.savedUsername(for: ssid),
                            for: ssid
                        )
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
