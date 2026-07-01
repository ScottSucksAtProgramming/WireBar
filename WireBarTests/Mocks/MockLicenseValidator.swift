import Foundation
@testable import WireBar

final class MockLicenseValidator: LicenseValidating, @unchecked Sendable {
    var activateResult: Result<LicenseActivationResult, Error> = .success(
        LicenseActivationResult(instanceId: "test-instance-id", licenseKeyStatus: "active", activationLimit: 5, activationUsage: 1)
    )
    var validateResult: Result<LicenseValidationResult, Error> = .success(
        LicenseValidationResult(valid: true, licenseKeyStatus: "active")
    )
    var deactivateResult: Result<LicenseDeactivationResult, Error> = .success(
        LicenseDeactivationResult(deactivated: true)
    )

    private(set) var activateCallCount = 0
    private(set) var validateCallCount = 0
    private(set) var deactivateCallCount = 0
    private(set) var lastActivateKey: String?
    private(set) var lastActivateInstanceName: String?

    func activate(licenseKey: String, instanceName: String) async throws -> LicenseActivationResult {
        activateCallCount += 1
        lastActivateKey = licenseKey
        lastActivateInstanceName = instanceName
        return try activateResult.get()
    }

    func validate(licenseKey: String, instanceId: String) async throws -> LicenseValidationResult {
        validateCallCount += 1
        return try validateResult.get()
    }

    func deactivate(licenseKey: String, instanceId: String) async throws -> LicenseDeactivationResult {
        deactivateCallCount += 1
        return try deactivateResult.get()
    }
}
