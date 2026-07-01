import XCTest
import Combine
@testable import WireBar

@MainActor
final class LicenseManagerTests: XCTestCase {

    private func makeSUT(
        validator: MockLicenseValidator = MockLicenseValidator(),
        keychain: InMemoryKeychainStorage = InMemoryKeychainStorage()
    ) -> (LicenseManager, MockLicenseValidator, InMemoryKeychainStorage) {
        let sut = LicenseManager(validator: validator, keychain: keychain)
        return (sut, validator, keychain)
    }

    // MARK: - Activation Success

    func testActivationSuccessSetsIsPaidTrue() async {
        let (sut, _, _) = makeSUT()

        let success = await sut.activateLicense(key: "test-key-1234")

        XCTAssertTrue(success)
        XCTAssertTrue(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .activated)
    }

    func testActivationSuccessStoresKeyInKeychain() async {
        let keychain = InMemoryKeychainStorage()
        let (sut, _, _) = makeSUT(keychain: keychain)

        _ = await sut.activateLicense(key: "test-key-1234")

        XCTAssertEqual(keychain.load(key: "license_key"), "test-key-1234")
        XCTAssertEqual(keychain.load(key: "instance_id"), "test-instance-id")
        XCTAssertNotNil(keychain.loadDate(key: "validation_timestamp"))
    }

    func testActivationSuccessExposesLicenseKey() async {
        let (sut, _, _) = makeSUT()

        _ = await sut.activateLicense(key: "ABCD-1234-EFGH")

        XCTAssertEqual(sut.licenseKey, "ABCD-1234-EFGH")
    }

    func testActivationSuccessClearsError() async {
        let validator = MockLicenseValidator()
        let (sut, _, _) = makeSUT(validator: validator)

        // First, fail
        validator.activateResult = .failure(LicenseAPIError.invalidKey)
        _ = await sut.activateLicense(key: "bad-key")
        XCTAssertNotNil(sut.lastError)

        // Then succeed
        validator.activateResult = .success(
            LicenseActivationResult(instanceId: "id", licenseKeyStatus: "active", activationLimit: 5, activationUsage: 1)
        )
        _ = await sut.activateLicense(key: "good-key")
        XCTAssertNil(sut.lastError)
    }

    // MARK: - Activation Failure (Invalid Key)

    func testActivationInvalidKeyKeepsIsPaidFalse() async {
        let validator = MockLicenseValidator()
        validator.activateResult = .failure(LicenseAPIError.invalidKey)
        let (sut, _, _) = makeSUT(validator: validator)

        let success = await sut.activateLicense(key: "bad-key")

        XCTAssertFalse(success)
        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.lastError, .invalidKey)
    }

    // MARK: - Activation Failure (Limit Reached)

    func testActivationLimitReachedKeepsIsPaidFalse() async {
        let validator = MockLicenseValidator()
        validator.activateResult = .failure(LicenseAPIError.activationLimitReached)
        let (sut, _, _) = makeSUT(validator: validator)

        let success = await sut.activateLicense(key: "limit-key")

        XCTAssertFalse(success)
        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.lastError, .activationLimitReached)
    }

    // MARK: - Validation Success

    func testValidationSuccessKeepsIsPaidTrue() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        let validator = MockLicenseValidator()
        validator.validateResult = .success(LicenseValidationResult(valid: true, licenseKeyStatus: "active"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // Init restored from keychain, now validate explicitly
        await sut.validateLicense()

        XCTAssertTrue(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .activated)
    }

    // MARK: - Validation Failure (Revoked)

    func testValidationRevokedSetsIsPaidFalse() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        let validator = MockLicenseValidator()
        validator.validateResult = .success(LicenseValidationResult(valid: false, licenseKeyStatus: "expired"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // Wait for init's background validation to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .free)
    }

    // MARK: - Validation Network Error Keeps User Paid

    func testValidationNetworkErrorKeepsUserPaid() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date())
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // Wait for init's background validation to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(sut.isPaid, "Network error during validation should NOT flip a paid user to free")
        XCTAssertEqual(sut.licenseStatus, .gracePeriod)
    }

    // MARK: - Deactivation

    func testDeactivationSetsIsPaidFalse() async {
        let (sut, _, _) = makeSUT()
        _ = await sut.activateLicense(key: "test-key")
        XCTAssertTrue(sut.isPaid)

        await sut.deactivateLicense()

        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .free)
        XCTAssertNil(sut.licenseKey)
    }

    func testDeactivationClearsKeychain() async {
        let keychain = InMemoryKeychainStorage()
        let (sut, _, _) = makeSUT(keychain: keychain)
        _ = await sut.activateLicense(key: "test-key")

        await sut.deactivateLicense()

        XCTAssertNil(keychain.load(key: "license_key"))
        XCTAssertNil(keychain.load(key: "instance_id"))
        XCTAssertNil(keychain.loadDate(key: "validation_timestamp"))
    }

    // MARK: - Launch With Stored Credentials

    func testLaunchWithStoredCredentialsKicksOffValidation() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        let validator = MockLicenseValidator()
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // On init, status should be activated from keychain
        XCTAssertEqual(sut.licenseStatus, .activated)
        XCTAssertEqual(sut.licenseKey, "stored-key")

        // Wait for background validation
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(validator.validateCallCount, 1)
    }

    func testLaunchWithNoStoredCredentialsStaysFree() {
        let (sut, validator, _) = makeSUT()

        XCTAssertEqual(sut.licenseStatus, .free)
        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(validator.validateCallCount, 0)
    }

    // MARK: - isPaid Setter Compatibility

    func testIsPaidSetterMapsToLicenseStatus() {
        let (sut, _, _) = makeSUT()

        sut.isPaid = true
        XCTAssertEqual(sut.licenseStatus, .activated)

        sut.isPaid = false
        XCTAssertEqual(sut.licenseStatus, .free)
    }

    // MARK: - Deactivation API (Phase 3)

    func testDeactivationAPISuccessClearsKeychainAndSetsFree() async {
        let keychain = InMemoryKeychainStorage()
        let validator = MockLicenseValidator()
        validator.deactivateResult = .success(LicenseDeactivationResult(deactivated: true))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)
        _ = await sut.activateLicense(key: "test-key")
        XCTAssertTrue(sut.isPaid)

        await sut.deactivateLicense()

        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .free)
        XCTAssertNil(sut.licenseKey)
        XCTAssertNil(keychain.load(key: "license_key"))
        XCTAssertNil(keychain.load(key: "instance_id"))
        XCTAssertNil(keychain.loadDate(key: "validation_timestamp"))
        XCTAssertNil(sut.lastError)
        XCTAssertEqual(validator.deactivateCallCount, 1)
    }

    func testDeactivationAPIReturnsFalseKeepsPaidAndSetsError() async {
        let keychain = InMemoryKeychainStorage()
        let validator = MockLicenseValidator()
        validator.deactivateResult = .success(LicenseDeactivationResult(deactivated: false))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)
        _ = await sut.activateLicense(key: "test-key")
        XCTAssertTrue(sut.isPaid)

        await sut.deactivateLicense()

        XCTAssertTrue(sut.isPaid, "License should stay active when API returns deactivated=false")
        XCTAssertEqual(sut.lastError, .deactivationFailed)
        XCTAssertNotNil(keychain.load(key: "license_key"), "Keychain should NOT be cleared on failed deactivation")
        XCTAssertNotNil(keychain.load(key: "instance_id"))
    }

    func testDeactivationNetworkErrorKeepsPaidAndPreservesKeychain() async {
        let keychain = InMemoryKeychainStorage()
        let validator = MockLicenseValidator()
        validator.deactivateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)
        _ = await sut.activateLicense(key: "test-key")
        XCTAssertTrue(sut.isPaid)

        await sut.deactivateLicense()

        XCTAssertTrue(sut.isPaid, "License should stay active on network error")
        XCTAssertEqual(sut.lastError, .networkError("No internet"))
        XCTAssertNotNil(keychain.load(key: "license_key"), "Keychain should NOT be cleared on network error")
        XCTAssertNotNil(keychain.load(key: "instance_id"))
    }

    func testDeactivationWithNoStoredCredentialsHandlesGracefully() async {
        let keychain = InMemoryKeychainStorage()
        let validator = MockLicenseValidator()
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)
        // Force to free state (BETA_UNLOCK_PAID may set activated in debug builds)
        sut.forceLocalDeactivation()
        XCTAssertFalse(sut.isPaid)

        await sut.deactivateLicense()

        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.licenseStatus, .free)
        XCTAssertEqual(validator.deactivateCallCount, 0, "Should not call API when no credentials stored")
        XCTAssertNil(sut.lastError)
    }

    // MARK: - Grace Period (Phase 2)

    func testNetworkErrorWithRecentTimestampSetsGracePeriod() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date().addingTimeInterval(-3 * 86400)) // 3 days ago
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        await sut.validateLicense()

        XCTAssertEqual(sut.licenseStatus, .gracePeriod)
        XCTAssertTrue(sut.isPaid, "Grace period should keep paid features active")
    }

    func testNetworkErrorWithExpiredTimestampSetsValidationPending() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date().addingTimeInterval(-8 * 86400)) // 8 days ago
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        await sut.validateLicense()

        XCTAssertEqual(sut.licenseStatus, .validationPending)
        XCTAssertFalse(sut.isPaid, "Expired grace period should disable paid features")
    }

    func testNetworkErrorWithNoTimestampSetsValidationPending() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        // No validation_timestamp saved
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        await sut.validateLicense()

        XCTAssertEqual(sut.licenseStatus, .validationPending)
        XCTAssertFalse(sut.isPaid, "No cached timestamp should disable paid features on network error")
    }

    func testClockTamperingDuringValidationSetsValidationPending() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date().addingTimeInterval(86400)) // 1 day in the future
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        await sut.validateLicense()

        XCTAssertEqual(sut.licenseStatus, .validationPending, "Clock rolled back should invalidate cached validation")
        XCTAssertFalse(sut.isPaid)
    }

    func testClockTamperingOnRestoreSetsValidationPending() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date().addingTimeInterval(86400)) // future
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // Clock-tampering check happens in both restoreFromKeychain and applyGracePeriodLogic.
        // With BETA_UNLOCK_PAID, restoreFromKeychain skips the check, but validateLicense still runs
        // and the grace period logic detects the future timestamp.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(sut.licenseStatus, .validationPending, "Clock tampering should not trust cache")
    }

    func testConnectivityRestoredTriggersRevalidationInGracePeriod() async {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "license_key", value: "stored-key")
        keychain.save(key: "instance_id", value: "stored-instance")
        keychain.saveDate(key: "validation_timestamp", value: Date())
        let validator = MockLicenseValidator()
        validator.validateResult = .failure(LicenseAPIError.networkError("No internet"))
        let (sut, _, _) = makeSUT(validator: validator, keychain: keychain)

        // Wait for init's background validation to set grace period
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(sut.licenseStatus, .gracePeriod)
        let callCountBefore = validator.validateCallCount

        // Now restore connectivity — validator succeeds
        validator.validateResult = .success(LicenseValidationResult(valid: true, licenseKeyStatus: "active"))
        sut.onConnectivityRestored()

        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(validator.validateCallCount, callCountBefore + 1)
        XCTAssertEqual(sut.licenseStatus, .activated)
        XCTAssertTrue(sut.isPaid)
    }

    func testConnectivityRestoredDoesNothingWhenFree() {
        let validator = MockLicenseValidator()
        let (sut, _, _) = makeSUT(validator: validator)
        // Force to free state (BETA_UNLOCK_PAID may set activated in debug builds)
        sut.forceLocalDeactivation()
        XCTAssertEqual(sut.licenseStatus, .free)

        sut.onConnectivityRestored()

        XCTAssertEqual(validator.validateCallCount, 0, "Should not validate when status is free")
    }
}
