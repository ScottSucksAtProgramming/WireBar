import SwiftUI
import AppKit

struct LicenseSettingsView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var licenseKeyInput: String = ""
    @State private var isActivating: Bool = false
    @State private var activationFailed: Bool = false
    @State private var isDeactivating: Bool = false
    @State private var showDeactivateConfirmation: Bool = false

    private func activateLicense() {
        nonisolated(unsafe) let manager = licenseManager
        let key = licenseKeyInput
        isActivating = true
        activationFailed = false
        Task {
            let success = await manager.activateLicense(key: key)
            await MainActor.run {
                if !success {
                    activationFailed = true
                }
                isActivating = false
            }
        }
    }

    private func deactivateLicense() {
        nonisolated(unsafe) let manager = licenseManager
        isDeactivating = true
        Task {
            await manager.deactivateLicense()
            await MainActor.run {
                isDeactivating = false
            }
        }
    }

    private var deactivationErrorMessage: String? {
        guard let error = licenseManager.lastError else { return nil }
        switch error {
        case .networkError:
            return String(localized: "Could not reach the license server. Please check your connection and try again.")
        case .deactivationFailed:
            return String(localized: "Deactivation failed. Please try again or contact support.")
        default:
            return nil
        }
    }

    var body: some View {
        Form {
            Section(String(localized: "Current Plan")) {
                LabeledContent(String(localized: "Plan")) {
                    Text(licenseManager.isPaid ? String(localized: "Paid") : String(localized: "Free"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(licenseManager.isPaid ? .green : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            (licenseManager.isPaid ? Color.green : Color.secondary).opacity(0.15),
                            in: Capsule()
                        )
                        .accessibilityLabel(String(localized: "Current plan: \(licenseManager.isPaid ? "Paid" : "Free")"))
                }
                if licenseManager.isPaid, let key = licenseManager.licenseKey {
                    LabeledContent(String(localized: "License Key")) {
                        Text("\(key.prefix(4))••••••••")
                            .accessibilityLabel(String(localized: "License key starting with \(key.prefix(4))"))
                    }
                }
            }

            if !licenseManager.isPaid {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "Upgrade to WireBar Pro"))
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(String(localized: "One-time purchase of $12.99. Unlock all features:"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            featureRow("network.badge.shield.half.filled", String(localized: "VPN monitoring and quick toggles"))
                            featureRow("globe", String(localized: "External/public IP address"))
                            featureRow("gauge.with.dots.needle.33percent", String(localized: "Ping/latency indicator"))
                            featureRow("bell.badge", String(localized: "VPN drop and IP change notifications"))
                            featureRow("keyboard", String(localized: "Global keyboard shortcuts"))
                            featureRow("slider.horizontal.3", String(localized: "Advanced network details and customization"))
                        }
                        .padding(.top, 2)

                        Button {
                            NSWorkspace.shared.open(LicenseConfig.checkoutURL)
                        } label: {
                            Text(String(localized: "Get a License — $12.99"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityLabel(String(localized: "Get a license for twelve dollars and ninety-nine cents"))
                        .accessibilityHint(String(localized: "Opens the WireBar website to purchase a license"))
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(String(localized: "Activate License")) {
                if !licenseManager.isPaid {
                    TextField(String(localized: "Enter license key"), text: $licenseKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(String(localized: "License key input"))

                    Button {
                        activateLicense()
                    } label: {
                        Text(isActivating ? String(localized: "Activating…") : String(localized: "Activate"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(licenseKeyInput.isEmpty || isActivating)
                    .accessibilityLabel(String(localized: "Activate license"))

                    if activationFailed {
                        Text(String(localized: "Invalid license key. Please try again."))
                            .foregroundStyle(.red)
                            .accessibilityLabel(String(localized: "Activation failed: Invalid license key. Please try again."))
                    }
                } else {
                    Text(String(localized: "Your license is active"))
                        .foregroundStyle(.green)
                        .accessibilityLabel(String(localized: "License is active"))

                    Button(String(localized: isDeactivating ? "Deactivating…" : "Deactivate License"), role: .destructive) {
                        showDeactivateConfirmation = true
                    }
                    .disabled(isDeactivating)
                    .accessibilityLabel(String(localized: "Deactivate license"))

                    if let message = deactivationErrorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityLabel(message)
                    }

                    Label {
                        Text(String(localized: "To transfer your license to another device, deactivate it here first, then enter the same license key on your new device."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "To transfer your license to another device, deactivate it here first, then enter the same license key on your new device."))
                }
            }
        }
        .formStyle(.grouped)
        .alert(
            String(localized: "Deactivate License?"),
            isPresented: $showDeactivateConfirmation
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Deactivate"), role: .destructive) {
                deactivateLicense()
            }
        } message: {
            Text(String(localized: "This will deactivate your license on this device. You can reactivate it on this or another device using the same license key."))
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
        }
        .accessibilityLabel(text)
    }
}
