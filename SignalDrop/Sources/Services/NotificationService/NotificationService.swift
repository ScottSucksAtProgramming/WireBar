import Foundation
import Combine

final class NotificationService: @unchecked Sendable {
    private let dispatcher: NotificationDispatching
    private let licenseManager: LicenseManager
    private let settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var previousVPNStates: [String: VPNConnectionStatus] = [:]
    private var previousWiFiConnected: Bool?
    private var previousExternalIP: String?
    private var hasReceivedInitialIP = false
    private var hasAuthorized = false

    init(
        dispatcher: NotificationDispatching = UNNotificationDispatcher(),
        licenseManager: LicenseManager,
        settingsStore: SettingsStore
    ) {
        self.dispatcher = dispatcher
        self.licenseManager = licenseManager
        self.settingsStore = settingsStore
    }

    func observeVPN(_ vpnManager: VPNManager) {
        vpnManager.$vpnStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                self?.handleVPNUpdate(states)
            }
            .store(in: &cancellables)
    }

    func observeNetwork(_ networkMonitor: NetworkMonitor) {
        networkMonitor.$state
            .map { state -> Bool in
                state.connectionType == .wifi || state.connectionType == .wifiAndEthernet
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isWiFiConnected in
                self?.handleWiFiUpdate(isWiFiConnected)
            }
            .store(in: &cancellables)
    }

    func observeIP(_ ipService: IPService) {
        ipService.$externalIPStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleIPUpdate(status)
            }
            .store(in: &cancellables)
    }

    private func handleVPNUpdate(_ states: [VPNState]) {
        guard licenseManager.isPaid, settingsStore.notifyVPNDrop else {
            previousVPNStates = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0.status) })
            return
        }

        for vpn in states {
            if let previous = previousVPNStates[vpn.id],
               previous == .connected,
               vpn.status == .disconnected {
                let title = String(localized: "VPN Disconnected")
                let body = String(localized: "\(vpn.displayName) has disconnected")
                ensureAuthorizedThenDispatch(title: title, body: body, identifier: "vpn-drop-\(vpn.id)")
            }
        }

        previousVPNStates = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0.status) })
    }

    private func handleWiFiUpdate(_ isWiFiConnected: Bool) {
        guard licenseManager.isPaid, settingsStore.notifyWiFiDisconnect else {
            previousWiFiConnected = isWiFiConnected
            return
        }

        if let wasConnected = previousWiFiConnected, wasConnected, !isWiFiConnected {
            let title = String(localized: "Wi-Fi Disconnected")
            let body = String(localized: "Your Wi-Fi connection has been lost")
            ensureAuthorizedThenDispatch(title: title, body: body, identifier: "wifi-disconnect")
        }

        previousWiFiConnected = isWiFiConnected
    }

    private func handleIPUpdate(_ status: ExternalIPStatus) {
        guard licenseManager.isPaid, settingsStore.notifyIPChange else {
            if case .loaded(let ip) = status {
                if !hasReceivedInitialIP { hasReceivedInitialIP = true }
                previousExternalIP = ip
            }
            return
        }

        guard case .loaded(let ip) = status else { return }

        defer { previousExternalIP = ip }

        guard hasReceivedInitialIP else {
            hasReceivedInitialIP = true
            return
        }

        guard let previous = previousExternalIP, previous != ip else { return }

        let title = String(localized: "External IP Changed")
        let body = String(localized: "Your external IP changed to \(ip)")
        ensureAuthorizedThenDispatch(title: title, body: body, identifier: "ip-change")
    }

    func handleWiFiUpdateForTesting(_ isWiFiConnected: Bool) {
        handleWiFiUpdate(isWiFiConnected)
    }

    func handleIPUpdateForTesting(_ status: ExternalIPStatus) {
        handleIPUpdate(status)
    }

    private func ensureAuthorizedThenDispatch(title: String, body: String, identifier: String) {
        Task {
            if !hasAuthorized {
                hasAuthorized = (try? await dispatcher.requestAuthorization()) ?? false
            }
            await dispatcher.dispatch(title: title, body: body, identifier: identifier)
        }
    }
}
