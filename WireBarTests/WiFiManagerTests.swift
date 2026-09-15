import XCTest
import Combine
@testable import WireBar

final class WiFiManagerTests: XCTestCase {
    private var mockScanner: MockWiFiScanner!
    private var mockKeychain: InMemoryKeychainStorage!

    override func setUp() {
        super.setUp()
        mockScanner = MockWiFiScanner()
        mockKeychain = InMemoryKeychainStorage()
    }

    // MARK: - Scanning

    func testScanReturnsNetworksSortedKnownFirst() {
        mockScanner.knownSSIDs = ["HomeNetwork"]
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "CoffeeShop", rssi: -40, isKnown: false),
            makeNetwork(ssid: "HomeNetwork", rssi: -60, isKnown: true),
        ]

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
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

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
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

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
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

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
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

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertTrue(sut.networks.first { $0.ssid == "HomeNetwork" }!.isCurrent)
        XCTAssertFalse(sut.networks.first { $0.ssid == "Other" }!.isCurrent)
    }

    func testScanFiltersOutNilSSIDNetworks() {
        mockScanner.networksToReturn = [
            makeNetwork(ssid: "Visible", rssi: -50, isKnown: false),
        ]

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertEqual(sut.networks.count, 1)
        XCTAssertEqual(sut.networks[0].ssid, "Visible")
    }

    func testScanFailureSetsErrorState() {
        mockScanner.scanShouldThrow = true

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        sut.scan()
        waitForScanToFinish(sut)

        XCTAssertTrue(sut.networks.isEmpty)
        XCTAssertNotNil(sut.scanError)
    }

    // MARK: - Join Network

    func testJoinKnownNetworkCallsAssociateWithNilPassword() {
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true, bssid: "AA:BB:CC:DD:EE:FF")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.ssid, "Home")
        XCTAssertNil(mockScanner.associateCalledWith?.password)
    }

    func testJoinUnknownNetworkCallsAssociateWithPassword() {
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false, bssid: "11:22:33:44:55:66")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "secret123")
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.ssid, "Cafe")
        XCTAssertEqual(mockScanner.associateCalledWith?.password, "secret123")
    }

    func testJoinFailureSetsJoinError() {
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Bad", rssi: -50, isKnown: false, bssid: "FF:FF:FF:FF:FF:FF")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "pw")
        waitForJoinToFinish(sut)

        XCTAssertNotNil(sut.joinError)
    }

    // MARK: - Stored Passwords

    func testSuccessfulJoinRemembersUserSuppliedPassword() {
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "secret123")
        waitForJoinToFinish(sut)

        // Assert on behaviour rather than the stored encoding: a later join must
        // reuse it without being given the password again.
        mockScanner.associateCalledWith = nil
        let reloaded = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        reloaded.joinNetwork(network, password: nil)
        waitForJoinToFinish(reloaded)

        XCTAssertEqual(mockScanner.associateCalledWith?.password, "secret123")
    }

    func testJoinReusesStoredPasswordWhenNoneSupplied() {
        mockKeychain.save(key: "Home", value: "stored-pw")
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.password, "stored-pw")
    }

    func testFailedJoinDoesNotDiscardStoredPassword() {
        mockKeychain.save(key: "Home", value: "stored-pw")
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        // Out of range, AP down and timeouts all fail here too -- a failure is not
        // evidence the password is wrong, so it must survive.
        XCTAssertEqual(mockKeychain.load(key: "Home"), "stored-pw")
    }

    func testFailedJoinDoesNotStorePassword() {
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "wrong-pw")
        waitForJoinToFinish(sut)

        XCTAssertNil(mockKeychain.load(key: "Cafe"))
    }

    func testJoinErrorNeverContainsThePassword() {
        mockScanner.associateShouldThrow = true
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "hunter2")
        waitForJoinToFinish(sut)

        let message = sut.joinError?.localizedDescription ?? ""
        XCTAssertFalse(message.contains("hunter2"))
    }

    // MARK: - Managing saved passwords

    func testSavePasswordAddsNetworkToSavedList() {
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        XCTAssertTrue(sut.savePassword("pw", username: nil, for: "Home"))

        XCTAssertEqual(sut.savedNetworkSSIDs, ["Home"])
        XCTAssertTrue(sut.hasSavedPassword(for: "Home"))
    }

    func testSavePasswordReplacesAnExistingOne() {
        mockKeychain.save(key: "Home", value: "old-pw")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        XCTAssertTrue(sut.savePassword("new-pw", username: nil, for: "Home"))

        XCTAssertEqual(sut.savedNetworkSSIDs, ["Home"])
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)
        XCTAssertEqual(mockScanner.associateCalledWith?.password, "new-pw")
    }

    func testForgetPasswordRemovesOnlyThatNetwork() {
        mockKeychain.save(key: "Home", value: "a")
        mockKeychain.save(key: "Cafe", value: "b")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.forgetPassword(for: "Home")

        XCTAssertEqual(sut.savedNetworkSSIDs, ["Cafe"])
    }

    func testForgetAllPasswordsClearsEveryNetwork() {
        mockKeychain.save(key: "Home", value: "a")
        mockKeychain.save(key: "Cafe", value: "b")
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.forgetAllPasswords()

        XCTAssertTrue(sut.savedNetworkSSIDs.isEmpty)
        XCTAssertNil(mockKeychain.load(key: "Home"))
        XCTAssertNil(mockKeychain.load(key: "Cafe"))
    }

    func testSavedListPicksUpAPasswordStoredByJoining() {
        let network = makeNetwork(ssid: "Cafe", rssi: -50, isKnown: false)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        XCTAssertTrue(sut.savedNetworkSSIDs.isEmpty)

        sut.joinNetwork(network, password: "secret123")
        waitForJoinToFinish(sut)

        XCTAssertEqual(sut.savedNetworkSSIDs, ["Cafe"])
    }

    func testSavedListIsPopulatedAtInit() {
        mockKeychain.save(key: "Home", value: "a")

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        XCTAssertEqual(sut.savedNetworkSSIDs, ["Home"])
    }

    // MARK: - Enterprise networks

    func testEnterpriseJoinUsesTheEnterpriseAssociation() {
        let network = makeNetwork(ssid: "CorpNet", rssi: -50, isKnown: false, securityType: .wpa2Enterprise)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "pw", username: "alice")
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.enterpriseAssociateCalledWith?.ssid, "CorpNet")
        XCTAssertEqual(mockScanner.enterpriseAssociateCalledWith?.username, "alice")
        XCTAssertEqual(mockScanner.enterpriseAssociateCalledWith?.password, "pw")
        XCTAssertNil(mockScanner.associateCalledWith)
    }

    func testEnterpriseJoinWithoutUsernameFailsWithoutAssociating() {
        let network = makeNetwork(ssid: "CorpNet", rssi: -50, isKnown: true, securityType: .wpa2Enterprise)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "pw", username: nil)
        waitForJoinToFinish(sut)

        XCTAssertNotNil(sut.joinError)
        XCTAssertNil(mockScanner.enterpriseAssociateCalledWith)
    }

    func testEnterpriseJoinRemembersTheUsername() {
        let network = makeNetwork(ssid: "CorpNet", rssi: -50, isKnown: false, securityType: .wpa2Enterprise)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "pw", username: "alice")
        waitForJoinToFinish(sut)

        XCTAssertEqual(sut.savedUsername(for: "CorpNet"), "alice")
    }

    func testEnterpriseJoinReusesStoredCredentials() {
        let network = makeNetwork(ssid: "CorpNet", rssi: -50, isKnown: true, securityType: .wpa2Enterprise)
        let seed = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        seed.joinNetwork(network, password: "pw", username: "alice")
        waitForJoinToFinish(seed)
        mockScanner.enterpriseAssociateCalledWith = nil

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        sut.joinNetwork(network, password: nil, username: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.enterpriseAssociateCalledWith?.username, "alice")
        XCTAssertEqual(mockScanner.enterpriseAssociateCalledWith?.password, "pw")
    }

    func testCorrectingOnlyTheUsernameIsPersisted() {
        let network = makeNetwork(ssid: "CorpNet", rssi: -50, isKnown: true, securityType: .wpa2Enterprise)
        let seed = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        seed.joinNetwork(network, password: "pw", username: "wrong")
        waitForJoinToFinish(seed)

        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        sut.joinNetwork(network, password: nil, username: "alice")
        waitForJoinToFinish(sut)

        XCTAssertEqual(sut.savedUsername(for: "CorpNet"), "alice")
    }

    func testChangingThePasswordKeepsTheUsername() {
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        XCTAssertTrue(sut.savePassword("pw", username: "alice", for: "CorpNet"))

        XCTAssertTrue(sut.savePassword("new-pw", username: sut.savedUsername(for: "CorpNet"), for: "CorpNet"))

        XCTAssertEqual(sut.savedUsername(for: "CorpNet"), "alice")
    }

    // MARK: - Entries written before usernames existed

    func testReadsALegacyBarePasswordEntry() {
        // Entries already on disk are the raw password, not JSON.
        mockKeychain.save(key: "Home", value: "legacy-pw")
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: nil)
        waitForJoinToFinish(sut)

        XCTAssertEqual(mockScanner.associateCalledWith?.password, "legacy-pw")
        XCTAssertNil(sut.savedUsername(for: "Home"))
    }

    func testRewritingALegacyEntryKeepsThePassword() {
        mockKeychain.save(key: "Home", value: "legacy-pw")
        let network = makeNetwork(ssid: "Home", rssi: -50, isKnown: true)
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.joinNetwork(network, password: "typed-pw")
        waitForJoinToFinish(sut)

        // Stored as JSON now, but still readable and still the right password.
        let reloaded = WiFiManager(scanner: mockScanner, keychain: mockKeychain)
        mockScanner.associateCalledWith = nil
        reloaded.joinNetwork(network, password: nil)
        waitForJoinToFinish(reloaded)

        XCTAssertEqual(mockScanner.associateCalledWith?.password, "typed-pw")
    }

    // MARK: - Power Toggle

    func testTogglePowerOff() {
        mockScanner.isPowered = true
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

        sut.togglePower()

        XCTAssertEqual(mockScanner.setPowerCalledWith, false)
        XCTAssertFalse(sut.isWiFiPoweredOn)
    }

    func testTogglePowerOn() {
        mockScanner.isPowered = false
        let sut = WiFiManager(scanner: mockScanner, keychain: mockKeychain)

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
        bssid: String = "00:00:00:00:00:00",
        securityType: NetworkSecurityType = .wpa2
    ) -> ScannedNetwork {
        ScannedNetwork(
            id: bssid,
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            channelNumber: 6,
            securityType: securityType,
            isKnown: isKnown,
            isCurrent: false
        )
    }
}
