import XCTest
@testable import WireBar

/// Exercises the real Keychain, not InMemoryKeychainStorage. The in-memory double
/// always reports success, so it cannot catch a store that the OS rejects outright --
/// which is exactly what happened when this used the data-protection keychain and
/// every write failed with -34018 errSecMissingEntitlement.
final class KeychainStorageTests: XCTestCase {
    private let service = "com.scottkostolni.WireBar.tests.keychain"
    private lazy var sut = KeychainStorage(service: service)

    override func tearDown() {
        sut.delete(key: "probe")
        super.tearDown()
    }

    func testSaveReportsSuccessAgainstTheRealKeychain() {
        XCTAssertTrue(sut.save(key: "probe", value: "value-1"),
                      "SecItemAdd was rejected by the OS -- check entitlements")
    }

    func testRoundTripsAValue() {
        XCTAssertTrue(sut.save(key: "probe", value: "value-1"))
        XCTAssertEqual(sut.load(key: "probe"), "value-1")
    }

    func testOverwritesAnExistingValue() {
        XCTAssertTrue(sut.save(key: "probe", value: "value-1"))
        XCTAssertTrue(sut.save(key: "probe", value: "value-2"))
        XCTAssertEqual(sut.load(key: "probe"), "value-2")
    }

    func testDeleteRemovesTheValue() {
        XCTAssertTrue(sut.save(key: "probe", value: "value-1"))
        XCTAssertTrue(sut.delete(key: "probe"))
        XCTAssertNil(sut.load(key: "probe"))
    }

    func testLoadReturnsNilForMissingKey() {
        XCTAssertNil(sut.load(key: "no-such-key"))
    }
}
