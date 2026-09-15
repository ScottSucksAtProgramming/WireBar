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
        // Remove everything the test created: residue here lands in a real login keychain.
        for key in sut.allKeys() {
            sut.delete(key: key)
        }
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

    func testAllKeysListsEveryStoredAccount() {
        XCTAssertTrue(sut.save(key: "probe", value: "a"))
        XCTAssertTrue(sut.save(key: "probe-2", value: "b"))
        XCTAssertTrue(sut.save(key: "probe-3", value: "c"))

        XCTAssertEqual(sut.allKeys(), ["probe", "probe-2", "probe-3"])
    }

    func testAllKeysIsEmptyWhenNothingStored() {
        XCTAssertTrue(sut.allKeys().isEmpty)
    }

    func testAllKeysIsScopedToThisService() {
        XCTAssertTrue(sut.save(key: "probe", value: "a"))

        let other = KeychainStorage(service: "com.scottkostolni.WireBar.tests.keychain.other")
        XCTAssertTrue(other.save(key: "not-mine", value: "b"))
        defer { other.delete(key: "not-mine") }

        XCTAssertEqual(sut.allKeys(), ["probe"])
    }

    func testAllKeysDropsDeletedAccounts() {
        XCTAssertTrue(sut.save(key: "probe", value: "a"))
        XCTAssertTrue(sut.save(key: "probe-2", value: "b"))
        XCTAssertTrue(sut.delete(key: "probe"))

        XCTAssertEqual(sut.allKeys(), ["probe-2"])
    }
}
