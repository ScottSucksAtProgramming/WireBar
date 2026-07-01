import Foundation

// MARK: - Response types

struct LicenseActivationResult: Sendable {
    let instanceId: String
    let licenseKeyStatus: String
    let activationLimit: Int
    let activationUsage: Int
}

struct LicenseValidationResult: Sendable {
    let valid: Bool
    let licenseKeyStatus: String
}

struct LicenseDeactivationResult: Sendable {
    let deactivated: Bool
}

// MARK: - Errors

enum LicenseAPIError: Error, Sendable, Equatable {
    case invalidKey
    case activationLimitReached
    case keyRevoked
    case networkError(String)
    case unexpectedResponse(String)
}

// MARK: - Protocol

protocol LicenseValidating: Sendable {
    func activate(licenseKey: String, instanceName: String) async throws -> LicenseActivationResult
    func validate(licenseKey: String, instanceId: String) async throws -> LicenseValidationResult
    func deactivate(licenseKey: String, instanceId: String) async throws -> LicenseDeactivationResult
}
