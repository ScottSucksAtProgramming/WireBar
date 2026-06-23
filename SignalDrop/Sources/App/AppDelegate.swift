import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let settingsStore = SettingsStore()
    let licenseManager = LicenseManager()
    private let networkMonitor = NetworkMonitor()
    private lazy var wifiManager = WiFiManager()
    private let locationManager = LocationPermissionManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager.requestPermissionIfNeeded()
        setupStatusItem()
        setupPopover()
        observeNetworkState()
        networkMonitor.start()
        wifiManager.scan()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: String(localized: "SignalDrop network status"))
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                networkMonitor: networkMonitor,
                wifiManager: wifiManager,
                settingsStore: settingsStore
            )
        )
    }

    private func observeNetworkState() {
        networkMonitor.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateMenuBarIcon(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateMenuBarIcon(for state: NetworkState) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if !state.isWiFiPoweredOn && state.connectionType != .ethernet && state.connectionType != .wifiAndEthernet {
            symbolName = "wifi.slash"
        } else {
            symbolName = switch state.connectionType {
            case .none: "wifi.slash"
            case .wifi: "wifi"
            case .ethernet: "cable.connector.horizontal"
            case .wifiAndEthernet: "wifi"
            }
        }

        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: String(localized: "SignalDrop network status")
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            wifiManager.scan()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
