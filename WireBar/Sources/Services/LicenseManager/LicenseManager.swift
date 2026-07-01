import Foundation
import Combine

enum LicenseStatus: Sendable, Equatable {
    case free
    case activated
    case gracePeriod
    case validationPending
}

enum LicenseError: Error, Sendable, Equatable {
    case invalidKey
    case activationLimitReached
    case networkError(String)
    case deactivationFailed
    case unknown(String)
}

final class LicenseManager: ObservableObject, @unchecked Sendable {
    @Published private(set) var licenseStatus: LicenseStatus = .free
    @Published private(set) var licenseKey: String?
    @Published private(set) var lastError: LicenseError?

    /// Computed for backward compatibility — used in 15+ views and 5+ test files.
    /// The setter allows tests to do `license.isPaid = true` without knowing about LicenseStatus.
    var isPaid: Bool {
        get { licenseStatus == .activated || licenseStatus == .gracePeriod }
        set { licenseStatus = newValue ? .activated : .free }
    }

    private let validator: LicenseValidating
    private let keychain: KeychainStoring

    private static let keychainLicenseKey = "license_key"
    private static let keychainInstanceId = "instance_id"
    private static let keychainValidationTimestamp = "validation_timestamp"

    init(
        validator: LicenseValidating = LemonSqueezyClient(),
        keychain: KeychainStoring = KeychainStorage()
    ) {
        self.validator = validator
        self.keychain = keychain
        restoreFromKeychain()
    }

    // MARK: - Public API

    func activateLicense(key: String) async -> Bool {
        setOnMain { manager in
            manager.lastError = nil
            manager.licenseStatus = .validationPending
        }

        do {
            let result = try await validator.activate(
                licenseKey: key,
                instanceName: LicenseConfig.hardwareUUID
            )

            keychain.save(key: Self.keychainLicenseKey, value: key)
            keychain.save(key: Self.keychainInstanceId, value: result.instanceId)
            keychain.saveDate(key: Self.keychainValidationTimestamp, value: Date())

            setOnMain { manager in
                manager.licenseKey = key
                manager.licenseStatus = .activated
                manager.lastError = nil
            }
            return true
        } catch let error as LicenseAPIError {
            let licenseError = Self.mapAPIError(error)
            setOnMain { manager in
                manager.licenseStatus = .free
                manager.lastError = licenseError
            }
            return false
        } catch {
            setOnMain { manager in
                manager.licenseStatus = .free
                manager.lastError = .networkError(error.localizedDescription)
            }
            return false
        }
    }

    func validateLicense() async {
        guard let key = keychain.load(key: Self.keychainLicenseKey),
              let instanceId = keychain.load(key: Self.keychainInstanceId)
        else { return }

        do {
            let result = try await validator.validate(licenseKey: key, instanceId: instanceId)

            if result.valid {
                keychain.saveDate(key: Self.keychainValidationTimestamp, value: Date())
                setOnMain { manager in
                    manager.licenseStatus = .activated
                }
            } else {
                // API explicitly says invalid/revoked — clear credentials
                clearCredentials()
                setOnMain { manager in
                    manager.licenseStatus = .free
                    manager.lastError = .invalidKey
                }
            }
        } catch {
            // Network error — check cached validation timestamp for grace period
            applyGracePeriodLogic()
        }
    }

    func deactivateLicense() async {
        setOnMain { manager in
            manager.lastError = nil
        }

        guard let key = keychain.load(key: Self.keychainLicenseKey),
              let instanceId = keychain.load(key: Self.keychainInstanceId)
        else {
            // No stored credentials — just clear local state
            forceLocalDeactivation()
            return
        }

        do {
            let result = try await validator.deactivate(licenseKey: key, instanceId: instanceId)
            if result.deactivated {
                forceLocalDeactivation()
            } else {
                setOnMain { manager in
                    manager.lastError = .deactivationFailed
                }
            }
        } catch let error as LicenseAPIError {
            let licenseError = Self.mapAPIError(error)
            setOnMain { manager in
                manager.lastError = licenseError
            }
        } catch {
            setOnMain { manager in
                manager.lastError = .networkError(error.localizedDescription)
            }
        }
    }

    /// Called when network connectivity is restored. Re-validates if in grace period
    /// or validation pending state to attempt full reactivation.
    func onConnectivityRestored() {
        guard licenseStatus == .gracePeriod || licenseStatus == .validationPending else { return }
        Task { await validateLicense() }
    }

    /// Clears local license state without calling the API.
    /// Used as a fallback when offline or when no credentials are stored.
    func forceLocalDeactivation() {
        clearCredentials()
        setOnMain { manager in
            manager.licenseStatus = .free
            manager.licenseKey = nil
            manager.lastError = nil
        }
    }

    // MARK: - Private

    private func restoreFromKeychain() {
        #if BETA_UNLOCK_PAID
        if ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil {
            licenseStatus = .activated
            return
        }
        #endif

        if let key = keychain.load(key: Self.keychainLicenseKey),
           let _ = keychain.load(key: Self.keychainInstanceId) {
            licenseKey = key

            // Clock-tampering check: if system time is before the stored validation
            // timestamp, the clock may have been rolled back — don't trust the cache.
            if let lastValidation = keychain.loadDate(key: Self.keychainValidationTimestamp),
               Date() < lastValidation {
                licenseStatus = .validationPending
            } else {
                licenseStatus = .activated
            }

            Task { await validateLicense() }
        }
    }

    private func applyGracePeriodLogic() {
        guard let lastValidation = keychain.loadDate(key: Self.keychainValidationTimestamp) else {
            // No cached timestamp — can't trust the license offline
            setOnMain { manager in
                manager.licenseStatus = .validationPending
            }
            return
        }

        // Clock-tampering: system time earlier than last validation
        guard Date() >= lastValidation else {
            setOnMain { manager in
                manager.licenseStatus = .validationPending
            }
            return
        }

        let daysSinceValidation = Calendar.current.dateComponents(
            [.day], from: lastValidation, to: Date()
        ).day ?? Int.max

        if daysSinceValidation < LicenseConfig.gracePeriodDays {
            setOnMain { manager in
                manager.licenseStatus = .gracePeriod
            }
        } else {
            setOnMain { manager in
                manager.licenseStatus = .validationPending
            }
        }
    }

    private func clearCredentials() {
        keychain.delete(key: Self.keychainLicenseKey)
        keychain.delete(key: Self.keychainInstanceId)
        keychain.delete(key: Self.keychainValidationTimestamp)
    }

    private func setOnMain(_ update: @escaping @Sendable (LicenseManager) -> Void) {
        if Thread.isMainThread {
            update(self)
        } else {
            nonisolated(unsafe) let manager = self
            DispatchQueue.main.async { update(manager) }
        }
    }

    private static func mapAPIError(_ error: LicenseAPIError) -> LicenseError {
        switch error {
        case .invalidKey:
            return .invalidKey
        case .activationLimitReached:
            return .activationLimitReached
        case .keyRevoked:
            return .invalidKey
        case .networkError(let message):
            return .networkError(message)
        case .unexpectedResponse(let message):
            return .unknown(message)
        }
    }
}
