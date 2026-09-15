import XCTest
import CryptoKit
@testable import WireBar

@MainActor
final class LicenseManagerBetaKeyTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private struct Fixture {
        let validator = MockLicenseValidator()
        let keychain = InMemoryKeychainStorage()
        let signingKey = Curve25519.Signing.PrivateKey()
        let clock = Clock()

        func makeSUT() -> LicenseManager {
            let clock = clock
            return LicenseManager(
                validator: validator,
                keychain: keychain,
                betaPublicKey: signingKey.publicKey,
                now: { clock.now }
            )
        }

        func makeKey(days: Double = 90) throws -> String {
            try BetaLicenseKey.make(
                name: "Alex",
                expiry: clock.now.addingTimeInterval(days * 86400),
                privateKey: signingKey
            )
        }
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    // MARK: - Activation

    func testValidBetaKeyUnlocksWithoutContactingLemonSqueezy() async throws {
        let fixture = Fixture()
        let sut = fixture.makeSUT()
        let key = try fixture.makeKey()

        let success = await sut.activateLicense(key: key)
        await drainMainQueue()

        XCTAssertTrue(success)
        XCTAssertTrue(sut.isPaid)
        XCTAssertEqual(sut.betaExpiry, fixture.clock.now.addingTimeInterval(90 * 86400))
        XCTAssertEqual(fixture.validator.activateCallCount, 0)
        XCTAssertEqual(fixture.keychain.load(key: "beta_license_key"), key)
        XCTAssertNil(fixture.keychain.load(key: "license_key"), "Beta key must not be stored where LemonSqueezy validation would wipe it")
    }

    func testExpiredBetaKeyIsRejected() async throws {
        let fixture = Fixture()
        let key = try fixture.makeKey(days: 90)
        fixture.clock.now = fixture.clock.now.addingTimeInterval(91 * 86400)
        let sut = fixture.makeSUT()

        let success = await sut.activateLicense(key: key)
        await drainMainQueue()

        XCTAssertFalse(success)
        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.lastError, .betaKeyExpired)
        XCTAssertNil(fixture.keychain.load(key: "beta_license_key"))
    }

    func testForgedBetaKeyIsRejected() async throws {
        let fixture = Fixture()
        let sut = fixture.makeSUT()
        let forged = try BetaLicenseKey.make(
            name: "Alex",
            expiry: fixture.clock.now.addingTimeInterval(90 * 86400),
            privateKey: Curve25519.Signing.PrivateKey()
        )

        let success = await sut.activateLicense(key: forged)
        await drainMainQueue()

        XCTAssertFalse(success)
        XCTAssertFalse(sut.isPaid)
        XCTAssertEqual(sut.lastError, .invalidKey)
        XCTAssertEqual(fixture.validator.activateCallCount, 0)
    }

    // MARK: - Relaunch

    func testStoredBetaKeySurvivesRelaunch() async throws {
        let fixture = Fixture()
        _ = await fixture.makeSUT().activateLicense(key: try fixture.makeKey())

        let relaunched = fixture.makeSUT()
        await drainMainQueue()

        XCTAssertTrue(relaunched.isPaid)
        XCTAssertNotNil(relaunched.betaExpiry)
        XCTAssertEqual(fixture.validator.validateCallCount, 0)
        XCTAssertNotNil(fixture.keychain.load(key: "beta_license_key"))
    }

    func testStoredBetaKeyPastItsEndDateLocksOnLaunch() async throws {
        let fixture = Fixture()
        fixture.keychain.save(key: "beta_license_key", value: try fixture.makeKey(days: 90))
        fixture.clock.now = fixture.clock.now.addingTimeInterval(91 * 86400)

        let sut = fixture.makeSUT()
        await drainMainQueue()

        XCTAssertFalse(sut.isPaid)
        XCTAssertNil(sut.betaExpiry)
        XCTAssertEqual(sut.lastError, .betaKeyExpired)
        XCTAssertNil(fixture.keychain.load(key: "beta_license_key"))
    }

    // MARK: - Expiry while running

    func testBetaKeyExpiringWhileRunningLocks() async throws {
        let fixture = Fixture()
        let sut = fixture.makeSUT()
        _ = await sut.activateLicense(key: try fixture.makeKey(days: 90))
        await drainMainQueue()
        XCTAssertTrue(sut.isPaid)

        fixture.clock.now = fixture.clock.now.addingTimeInterval(91 * 86400)
        sut.refreshBetaExpiry()
        await drainMainQueue()

        XCTAssertFalse(sut.isPaid)
        XCTAssertNil(sut.betaExpiry)
        XCTAssertEqual(sut.lastError, .betaKeyExpired)
    }

    // MARK: - Deactivation

    func testDeactivatingBetaKeyClearsItWithoutContactingLemonSqueezy() async throws {
        let fixture = Fixture()
        let sut = fixture.makeSUT()
        _ = await sut.activateLicense(key: try fixture.makeKey())
        await drainMainQueue()

        await sut.deactivateLicense()
        await drainMainQueue()

        XCTAssertFalse(sut.isPaid)
        XCTAssertNil(sut.betaExpiry)
        XCTAssertNil(sut.licenseKey)
        XCTAssertNil(fixture.keychain.load(key: "beta_license_key"))
        XCTAssertEqual(fixture.validator.deactivateCallCount, 0)
    }
}
