import SwiftUI

struct PasswordInputView: View {
    let networkName: String
    let isEnterprise: Bool
    let initialUsername: String?
    let onJoin: (_ username: String?, _ password: String) -> Void
    let onCancel: () -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    private var canJoin: Bool {
        !password.isEmpty && (!isEnterprise || !username.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isEnterprise
                ? String(localized: "Sign in to \"\(networkName)\"")
                : String(localized: "Enter password for \"\(networkName)\""))
                .font(.caption)
                .foregroundStyle(.secondary)

            if isEnterprise {
                TextField(String(localized: "Username"), text: $username)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel(String(localized: "Username for \(networkName)"))
            }

            HStack(spacing: 8) {
                SecureField(String(localized: "Password"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        if canJoin { onJoin(isEnterprise ? username : nil, password) }
                    }
                    .accessibilityLabel(String(localized: "Wi-Fi password for \(networkName)"))

                Button(String(localized: "Join")) {
                    onJoin(isEnterprise ? username : nil, password)
                }
                .disabled(!canJoin)
                .accessibilityLabel(String(localized: "Join \(networkName)"))

                Button(String(localized: "Cancel")) {
                    onCancel()
                }
                .accessibilityLabel(String(localized: "Cancel joining network"))
            }

            // An 802.1X network takes a work or school account, not a shared Wi-Fi
            // key, so say plainly what is being kept.
            Text(isEnterprise
                ? String(localized: "WireBar saves this account in your Mac's keychain so it won't ask again. It stays on this Mac.")
                : String(localized: "WireBar saves this in your Mac's keychain so it won't ask again. It stays on this Mac."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .onAppear {
            username = initialUsername ?? ""
            focusedField = (isEnterprise && username.isEmpty) ? .username : .password
        }
    }
}
