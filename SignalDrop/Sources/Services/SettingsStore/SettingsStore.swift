import Foundation
import Combine

final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadSettings()
    }

    @Published var launchAtLogin: Bool = true {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var showNetworkName: Bool = true {
        didSet { defaults.set(showNetworkName, forKey: Keys.showNetworkName) }
    }

    @Published var showSignalStrength: Bool = true {
        didSet { defaults.set(showSignalStrength, forKey: Keys.showSignalStrength) }
    }

    private func loadSettings() {
        if defaults.object(forKey: Keys.launchAtLogin) != nil {
            launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        }
        if defaults.object(forKey: Keys.showNetworkName) != nil {
            showNetworkName = defaults.bool(forKey: Keys.showNetworkName)
        }
        if defaults.object(forKey: Keys.showSignalStrength) != nil {
            showSignalStrength = defaults.bool(forKey: Keys.showSignalStrength)
        }
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let showNetworkName = "showNetworkName"
        static let showSignalStrength = "showSignalStrength"
    }
}
