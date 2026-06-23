import XCTest
@testable import SignalDrop

final class SettingsStoreTests: XCTestCase {
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.scottkostolni.SignalDrop.tests")!
        testDefaults.removePersistentDomain(forName: "com.scottkostolni.SignalDrop.tests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.scottkostolni.SignalDrop.tests")
        testDefaults = nil
        super.tearDown()
    }

    func testDefaultLaunchAtLoginIsTrue() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertTrue(store.launchAtLogin)
    }

    func testSetLaunchAtLoginPersists() {
        let store = SettingsStore(defaults: testDefaults)
        store.launchAtLogin = false

        let store2 = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store2.launchAtLogin)
    }

    func testDefaultShowNetworkNameIsTrue() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertTrue(store.showNetworkName)
    }

    func testSetShowNetworkNamePersists() {
        let store = SettingsStore(defaults: testDefaults)
        store.showNetworkName = false

        let store2 = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store2.showNetworkName)
    }

    func testDefaultShowBandIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showBand)
    }

    func testDefaultShowChannelIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showChannel)
    }

    func testDefaultShowLinkSpeedIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showLinkSpeed)
    }

    func testDefaultShowBSSIDIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showBSSID)
    }

    func testDefaultShowDNSIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showDNS)
    }

    func testDefaultShowGatewayIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showGateway)
    }

    func testDefaultShowSubnetIsFalse() {
        let store = SettingsStore(defaults: testDefaults)
        XCTAssertFalse(store.showSubnet)
    }

    func testSetShowBandPersists() {
        let store = SettingsStore(defaults: testDefaults)
        store.showBand = true

        let store2 = SettingsStore(defaults: testDefaults)
        XCTAssertTrue(store2.showBand)
    }
}
