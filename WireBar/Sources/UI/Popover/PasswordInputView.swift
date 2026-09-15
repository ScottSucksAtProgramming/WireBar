import SwiftUI

struct PasswordInputView: View {
    let networkName: String
    let onJoin: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Enter password for \"\(networkName)\""))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SecureField(String(localized: "Password"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($isPasswordFocused)
                    .onSubmit {
                        if !password.isEmpty {
                            onJoin(password)
                        }
                    }
                    .accessibilityLabel(String(localized: "Wi-Fi password for \(networkName)"))

                Button(String(localized: "Join")) {
                    onJoin(password)
                }
                .disabled(password.isEmpty)
                .accessibilityLabel(String(localized: "Join \(networkName)"))

                Button(String(localized: "Cancel")) {
                    onCancel()
                }
                .accessibilityLabel(String(localized: "Cancel joining network"))
            }

            Text(String(localized: "WireBar saves this in your Mac's keychain so it won't ask again. It stays on this Mac."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .onAppear {
            isPasswordFocused = true
        }
    }
}
