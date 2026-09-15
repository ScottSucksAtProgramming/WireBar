import Foundation
@testable import WireBar

// LicenseManager validates from a background Task at init while tests call it too,
// so every stored property is guarded by a lock.
final class MockLicenseValidator: LicenseValidating, @unchecked Sendable {
    private let lock = NSLock()

    private var _activateResult: Result<LicenseActivationResult, Error> = .success(
        LicenseActivationResult(instanceId: "test-instance-id", licenseKeyStatus: "active", activationLimit: 5, activationUsage: 1)
    )
    private var _validateResult: Result<LicenseValidationResult, Error> = .success(
        LicenseValidationResult(valid: true, licenseKeyStatus: "active")
    )
    private var _deactivateResult: Result<LicenseDeactivationResult, Error> = .success(
        LicenseDeactivationResult(deactivated: true)
    )
    private var _activateCallCount = 0
    private var _validateCallCount = 0
    private var _deactivateCallCount = 0
    private var _lastActivateKey: String?
    private var _lastActivateInstanceName: String?

    var activateResult: Result<LicenseActivationResult, Error> {
        get { lock.withLock { _activateResult } }
        set { lock.withLock { _activateResult = newValue } }
    }
    var validateResult: Result<LicenseValidationResult, Error> {
        get { lock.withLock { _validateResult } }
        set { lock.withLock { _validateResult = newValue } }
    }
    var deactivateResult: Result<LicenseDeactivationResult, Error> {
        get { lock.withLock { _deactivateResult } }
        set { lock.withLock { _deactivateResult = newValue } }
    }

    var activateCallCount: Int { lock.withLock { _activateCallCount } }
    var validateCallCount: Int { lock.withLock { _validateCallCount } }
    var deactivateCallCount: Int { lock.withLock { _deactivateCallCount } }
    var lastActivateKey: String? { lock.withLock { _lastActivateKey } }
    var lastActivateInstanceName: String? { lock.withLock { _lastActivateInstanceName } }

    func activate(licenseKey: String, instanceName: String) async throws -> LicenseActivationResult {
        let result = lock.withLock {
            _activateCallCount += 1
            _lastActivateKey = licenseKey
            _lastActivateInstanceName = instanceName
            return _activateResult
        }
        return try result.get()
    }

    func validate(licenseKey: String, instanceId: String) async throws -> LicenseValidationResult {
        let result = lock.withLock {
            _validateCallCount += 1
            return _validateResult
        }
        return try result.get()
    }

    func deactivate(licenseKey: String, instanceId: String) async throws -> LicenseDeactivationResult {
        let result = lock.withLock {
            _deactivateCallCount += 1
            return _deactivateResult
        }
        return try result.get()
    }
}
