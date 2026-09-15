import AppKit
import SwiftUI
import Combine
import Sparkle
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let settingsStore = SettingsStore()
    let licenseManager = LicenseManager()
    private let networkMonitor = NetworkMonitor()
    private lazy var wifiManager = WiFiManager()
    private let locationManager = LocationPermissionManager()
    private lazy var ipService = IPService(licenseManager: licenseManager)
    private lazy var pingService = PingService(licenseManager: licenseManager)
    lazy var vpnManager = VPNManager(licenseManager: licenseManager)
    private lazy var notificationService = NotificationService(licenseManager: licenseManager, settingsStore: settingsStore)
    private lazy var hotkeyManager = HotkeyManager(licenseManager: licenseManager, settingsStore: settingsStore)
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingLaunchAtLogin = false
    private var settingsWindow: NSWindow?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager.requestPermissionIfNeeded()
        setupStatusItem()
        setupPopover()
        observeNetworkState()
        networkMonitor.start()
        wifiManager.scan()
        ipService.refreshLocalIP()
        ipService.observeSettings(settingsStore)
        observePingSettings()
        vpnManager.refresh()
        observeVPNStateChanges()
        setupNotificationService()
        setupHotkeyManager()
        setupLaunchAtLogin()
        showLocationAlertIfNeeded()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: String(localized: "WireBar network status"))
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
                settingsStore: settingsStore,
                ipService: ipService,
                pingService: pingService,
                vpnManager: vpnManager,
                licenseManager: licenseManager,
                locationPermissionManager: locationManager,
                onOpenSettings: { [weak self] in
                    self?.openSettings()
                }
            )
        )
    }

    private func observeNetworkState() {
        networkMonitor.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        settingsStore.$menuBarShowNetworkName
            .combineLatest(settingsStore.$menuBarShowVPNIndicator, settingsStore.$menuBarShowIP)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        settingsStore.$menuBarShowSignalStrength
            .combineLatest(settingsStore.$menuBarSignalFormat, settingsStore.$menuBarShowHotspot)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        vpnManager.$vpnStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        ipService.$localIP
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &cancellables)
    }

    private func updateMenuBar() {
        guard let button = statusItem.button else { return }
        let state = networkMonitor.state
        let isPaid = licenseManager.isPaid

        let isDisconnected = (!state.isWiFiPoweredOn && state.connectionType != .ethernet && state.connectionType != .wifiAndEthernet)
            || state.connectionType == .none
        let isEthernetOnly = state.connectionType == .ethernet
        let isWiFiActive = state.connectionType == .wifi || state.connectionType == .wifiAndEthernet
        let showHotspot = isWiFiActive && state.isHotspot && settingsStore.menuBarShowHotspot && isPaid
        let showSignal = isWiFiActive && settingsStore.menuBarShowSignalStrength

        if isDisconnected {
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right.slash",
                accessibilityDescription: String(localized: "WireBar: no connection")
            )
        } else if isEthernetOnly {
            button.image = NSImage(
                systemSymbolName: "cable.connector.horizontal",
                accessibilityDescription: String(localized: "WireBar: Ethernet connected")
            )
        } else if showHotspot {
            button.image = NSImage(
                systemSymbolName: "personalhotspot",
                accessibilityDescription: String(localized: "WireBar: connected to personal hotspot")
            )
        } else if showSignal {
            let rssi = state.signalStrength
            let variableValue = max(0, min(1, Double(rssi + 100) / 80.0))
            let signalDescription = String(localized: "WireBar: Wi-Fi signal \(state.signalQuality.localizedDescription)")
            button.image = NSImage(
                systemSymbolName: "wifi",
                variableValue: variableValue,
                accessibilityDescription: signalDescription
            )
        } else {
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right",
                accessibilityDescription: String(localized: "WireBar network status")
            )
        }

        var textParts: [String] = []

        if settingsStore.menuBarShowNetworkName, isPaid, let ssid = state.ssid {
            let maxLen = 15
            textParts.append(ssid.count > maxLen ? String(ssid.prefix(maxLen)) + "…" : ssid)
        }

        if settingsStore.menuBarShowVPNIndicator, isPaid {
            let connectedCount = vpnManager.connectedCount
            if connectedCount > 0 {
                textParts.append("🔒\(connectedCount)")
            }
        }

        if settingsStore.menuBarShowIP, isPaid, let ip = ipService.localIP {
            textParts.append(ip)
        }

        if showSignal, isPaid {
            let rssi = state.signalStrength
            let format = SignalDisplayFormat(rawValue: settingsStore.menuBarSignalFormat) ?? .bars
            switch format {
            case .bars:
                break
            case .percentage:
                let pct = max(0, min(100, (rssi + 100) * 100 / 80))
                textParts.append("\(pct)%")
            case .dBm:
                textParts.append("\(rssi) dBm")
            }
        }

        button.title = textParts.isEmpty ? "" : " " + textParts.joined(separator: " · ")
        button.imagePosition = textParts.isEmpty ? .imageOnly : .imageLeading

        var accessibilityParts = [String(localized: "WireBar")]
        if let ssid = state.ssid { accessibilityParts.append(ssid) }
        if showSignal {
            accessibilityParts.append(String(localized: "Signal: \(state.signalQuality.localizedDescription)"))
        }
        if showHotspot {
            accessibilityParts.append(String(localized: "Personal hotspot"))
        }
        let vpnCount = vpnManager.connectedCount
        if vpnCount > 0 { accessibilityParts.append(String(localized: "\(vpnCount) VPN connected")) }
        button.setAccessibilityLabel(accessibilityParts.joined(separator: ", "))
    }

    private func openSettings() {
        popover.performClose(nil)

        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settingsStore: settingsStore,
            licenseManager: licenseManager,
            vpnManager: vpnManager,
            updaterController: updaterController
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "WireBar Settings")
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 780, height: 650))
        window.minSize = NSSize(width: 700, height: 450)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    private func setupLaunchAtLogin() {
        syncLaunchAtLoginWithSystem()

        // No .receive(on:) here: AppDelegate is @MainActor and the only writers are
        // the Settings toggle and setLaunchAtLoginWithoutApplying(_:). Synchronous
        // delivery is what lets isSyncingLaunchAtLogin suppress our own writes.
        settingsStore.$launchAtLogin
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self, !self.isSyncingLaunchAtLogin else { return }
                self.applyLaunchAtLogin(enabled, showErrors: true)
            }
            .store(in: &cancellables)
    }

    /// The system is the source of truth: the user can remove the login item in
    /// System Settings without the app knowing, so mirror the real status into the
    /// toggle. On first run there is no stored preference yet, so honour the default.
    private func syncLaunchAtLoginWithSystem() {
        let status = SMAppService.mainApp.status

        // .requiresApproval means macOS is waiting on the user, not that it's off.
        let isEnabled = (status == .enabled || status == .requiresApproval)

        guard settingsStore.hasLaunchAtLoginPreference else {
            // Errors are silent here: an unsigned build, or one run from a disk image
            // or DerivedData, is expected to fail, and a modal alert would block launch.
            if settingsStore.launchAtLogin, !isEnabled {
                applyLaunchAtLogin(true, showErrors: false)
            }
            // Persist the choice so a later removal in System Settings isn't undone
            // by this first-run branch on the next launch.
            setLaunchAtLoginWithoutApplying(settingsStore.launchAtLogin)
            return
        }

        guard settingsStore.launchAtLogin != isEnabled else { return }
        setLaunchAtLoginWithoutApplying(isEnabled)
    }

    private func applyLaunchAtLogin(_ enabled: Bool, showErrors: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            setLaunchAtLoginWithoutApplying(!enabled)
            if showErrors {
                showLaunchAtLoginError(error, wasEnabling: enabled)
            }
        }
    }

    private func setLaunchAtLoginWithoutApplying(_ value: Bool) {
        isSyncingLaunchAtLogin = true
        settingsStore.launchAtLogin = value
        isSyncingLaunchAtLogin = false
    }

    private func showLaunchAtLoginError(_ error: Error, wasEnabling: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = wasEnabling
            ? String(localized: "Couldn't turn on Launch at Login")
            : String(localized: "Couldn't turn off Launch at Login")
        if SMAppService.mainApp.status == .requiresApproval {
            alert.informativeText = String(localized: "macOS needs your approval. Open System Settings > General > Login Items and allow WireBar.")
        } else {
            alert.informativeText = String(localized: "macOS reported: \(error.localizedDescription)\n\nIf WireBar is running from a disk image or your Downloads folder, move it to your Applications folder and try again.")
        }
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func showLocationAlertIfNeeded() {
        guard !locationManager.isAuthorized, !settingsStore.locationAlertSuppressed else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }

            let alert = NSAlert()
            alert.messageText = String(localized: "Location Services Required")
            alert.informativeText = String(localized: "WireBar needs Location Services permission to show your Wi-Fi network name. Without it, the network name will appear as unavailable.")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "Open Settings"))
            alert.addButton(withTitle: String(localized: "Not Now"))
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(localized: "Don't remind me again")

            let response = alert.runModal()

            if let suppressionButton = alert.suppressionButton, suppressionButton.state == .on {
                self.settingsStore.locationAlertSuppressed = true
            }

            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func observePingSettings() {
        settingsStore.$showPing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showPing in
                guard let self else { return }
                if showPing && licenseManager.isPaid {
                    pingService.target = settingsStore.pingTarget
                    pingService.port = settingsStore.pingPort
                    pingService.start()
                } else {
                    pingService.stop()
                }
            }
            .store(in: &cancellables)

        settingsStore.$pingTarget
            .combineLatest(settingsStore.$pingPort)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] target, port in
                guard let self, pingService.isRunning else { return }
                pingService.target = target
                pingService.port = port
                pingService.measureOnce()
            }
            .store(in: &cancellables)
    }

    private func observeVPNStateChanges() {
        vpnManager.$vpnStates
            .map { states in states.filter { $0.status == .connected }.count }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, licenseManager.isPaid else { return }
                ipService.clearCache()
                ipService.refreshExternalIP()
            }
            .store(in: &cancellables)
    }

    private func setupHotkeyManager() {
        hotkeyManager.actionHandler = self
        hotkeyManager.start()
    }

    private func setupNotificationService() {
        notificationService.observeVPN(vpnManager)
        notificationService.observeNetwork(networkMonitor)
        notificationService.observeIP(ipService)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            wifiManager.scan()
            ipService.refreshLocalIP()
            ipService.refreshExternalIP()
            vpnManager.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

extension AppDelegate: HotkeyActionHandler {
    func performHotkeyAction(_ action: HotkeyAction) {
        switch action {
        case .togglePopover:
            togglePopover()
        case .toggleWiFi:
            wifiManager.togglePower()
        case .refreshIP:
            ipService.clearCache()
            ipService.refreshExternalIP()
        case .copyLocalIP:
            if let ip = ipService.localIP {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ip, forType: .string)
            }
        case .copyExternalIP:
            if let ip = ipService.externalIP {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ip, forType: .string)
            }
        }
    }
}
