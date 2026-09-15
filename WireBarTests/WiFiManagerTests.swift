import XCTest
import Combine
@testable import WireBar

final class WiFiManagerTests: XCTestCase {
    private var mockScanner: MockWiFiScanner!

    override func setUp() {
        super.setUp()
        mockScanner = MockWiFiScanner()
    }

    // MARK: - Scanning

    func testScanReturnsNetworksSortedKnownFirst() {
        mockScanner.knownSSIDs = ["HomeNetwork"]
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "CoffeeShop", rssi: -40, isKnown: false),
            makeNetwork(ssid: "HomeNetwork", rssi: -60, isKnown: true),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.count, 2)
        XCTAssertEqual(sut.networks[0].ssid, "HomeNetwork")
        XCTAssertEqual(sut.networks[1].ssid, "CoffeeShop")
    }

    func testScanSortsWithinGroupBySignalStrength() {
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "Weak", rssi: -80, isKnown: false),
            makeNetwork(ssid: "Strong", rssi: -30, isKnown: false),
            makeNetwork(ssid: "Medium", rssi: -55, isKnown: false),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.map(\.ssid), ["Strong", "Medium", "Weak"])
    }

    func testScanCollapsesDuplicateSSIDsKeepingStrongest() {
        mockScanner.currentSSIDValue = nil
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "AMB-Public", rssi: -70, isKnown: true, bssid: "AA:00:00:00:00:01"),
            makeNetwork(ssid: "AMB-Public", rssi: -45, isKnown: true, bssid: "AA:00:00:00:00:02"),
            makeNetwork(ssid: "AMB-Public", rssi: -82, isKnown: true, bssid: "AA:00:00:00:00:03"),
            makeNetwork(ssid: "AMB-Public", rssi: -61, isKnown: true, bssid: "AA:00:00:00:00:04"),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.count, 1)
        XCTAssertEqual(sut.networks.first?.rssi, -45)
    }

    func testScanKeepsDistinctSSIDs() {
        mockScanner.currentSSIDValue = nil
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "AMB-Public", rssi: -70, isKnown: false, bssid: "AA:00:00:00:00:01"),
            makeNetwork(ssid: "AMB-Public", rssi: -45, isKnown: false, bssid: "AA:00:00:00:00:02"),
            makeNetwork(ssid: "SBMA", rssi: -75, isKnown: false, bssid: "BB:00:00:00:00:01"),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.map(\.ssid), ["AMB-Public", "SBMA"])
    }

    func testScanMarksCurrentNetwork() {
        mockScanner.currentSSIDValue = "HomeNetwork"
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "HomeNetwork", rssi: -50, isKnown: false),
            makeNetwork(ssid: "Other", rssi: -60, isKnown: false),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertTrue(sut.networks.first { $0.ssid == "HomeNetwork" }!.isCurrent)
        XCTAssertFalse(sut.networks.first { $0.ssid == "Other" }!.isCurrent)
    }

    func testScanFiltersOutNilSSIDNetworks() {
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "Visible", rssi: -50, isKnown: false),
        ]

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.count, 1)
        XCTAssertEqual(sut.networks[0].ssid, "Visible")
    }

    func testScanFailureSetsErrorState() {
        mockScanner.scanShouldThrow = true

        let sut = WiFiManager(scanner: mockScanner)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertTrue(sut.networks.isEmpty)
        XCTAssertNotNil(sut.scanError)
    }

    // MARK: - Join Network

    func testJoinKnownNetworkCallsAssociateWithNilPassword() {
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true, bssid: "AA:BB:CC:DD:EE:FF")
        let sut = WiFiManager(scanner: mockScanner)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.ssid, "Home")
        XCTAssertNil(mockScanner.associateCalledWith?.password)
    }

    func testJoinUnknownNetworkCallsAssociateWithPassword() {
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false, bssid: "11:22:33:44:55:66")
        let sut = WiFiManager(scanner: mockScanner)

        sut.joinNetwork(network, password: "secret123")
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.ssid, "Cafe")
        XCTAssertEqual(mockScanner.associateCalledWith?.password, "secret123")
    }

    func testJoinFailureSetsJoinError() {
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Bad", rssi: -50, isKnown: false, bssid: "FF:FF:FF:FF:FF:FF")
        let sut = WiFiManager(scanner: mockScanner)

        sut.joinNetwork(network, password: "pw")
        waitForJoinToFinish(sut)

        XCTAssertNotNil(sut.joinError)
    }

    // MARK: - Stored Passwords

    func testSuccessfulJoinRemembersUserSuppliedPassword() {
        let keychain = InMemoryKeychainStorage()
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: keychain)

        sut.joinNetwork(network, password: "secret123")
        waitForJoinToFinish(sut)

        XCTAssertEqual(keychain.load(key: "Cafe"), "secret123")
    }

    func testJoinReusesStoredPasswordWhenNoneSupplied() {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "Home", value: "stored-pw")
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: keychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.password, "stored-pw")
    }

    func testFailedJoinDoesNotDiscardStoredPassword() {
        let keychain = InMemoryKeychainStorage()
        keychain.save(key: "Home", value: "stored-pw")
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: keychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        // Out of range, AP down and timeouts all fail here too -- a failure is not
        // evidence the password is wrong, so it must survive.
        XCTAssertEqual(keychain.load(key: "Home"), "stored-pw")
    }

    func testFailedJoinDoesNotStorePassword() {
        let keychain = InMemoryKeychainStorage()
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: keychain)

        sut.joinNetwork(network, password: "wrong-pw")
        waitForJoinToFinish(sut)

        XCTAssertNil(keychain.load(key: "Cafe"))
    }

    func testJoinErrorNeverContainsThePassword() {
        let keychain = InMemoryKeychainStorage()
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: keychain)

        sut.joinNetwork(network, password: "hunter2")
        waitForJoinToFinish(sut)

        let message = sut.joinError?.localizedDescription ?? ""
        XCTAssertFalse(message.contains("hunter2"))
    }

    // MARK: - Power Toggle

    func testTogglePowerOff() {
        mockScanner.isPowered = true
        let sut = WiFiManager(scanner: mockScanner)

        sut.togglePower()

        XCTAssertEqual(mockScanner.setPowerCalledWith, false)
        XCTAssertFalse(sut.isWiFiPoweredOn)
    }

    func testTogglePowerOn() {
        mockScanner.isPowered = false
        let sut = WiFiManager(scanner: mockScanner)

        sut.togglePower()

        XCTAssertEqual(mockScanner.setPowerCalledWith, true)
        XCTAssertTrue(sut.isWiFiPoweredOn)
    }

    // MARK: - Helpers

    private func waitForJoinToFinish(_ manager: WiFiManager, timeout: TimeInterval = 2) {
        let expectation = XCTestExpectation(description: "Join completes")
        var cancellable: AnyCancellable?
        cancellable = manager.$isJoining
            .dropFirst()
            .filter { !$0 }
            .sink { _ in
                expectation.fulfill()
                cancellable?.cancel()
            }
        wait(for: [expectation], timeout: timeout)
    }

    private func waitForScanToFinish(_ manager: WiFiManager, timeout: TimeInterval = 2) {
        let expectation = XCTestExpectation(description: "Scan completes")
        var cancellable: AnyCancellable?
        cancellable = manager.$isScanning
            .dropFirst()
            .filter { !$0 }
            .sink { _ in
                expectation.fulfill()
                cancellable?.cancel()
            }
        wait(for: [expectation], timeout: timeout)
    }

    private func makeNetwork(
        ssid: String,
        rssi: Int,
        isKnown: Bool,
        bssid: String = "00:00:00:00:00:00"
    ) -> ScannedNetwork {
        ScannedNetwork(
            id: bssid,
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            channelNumber: 6,
            securityType: .wpa2,
            isKnown: isKnown,
            isCurrent: false
        )
    }
}
