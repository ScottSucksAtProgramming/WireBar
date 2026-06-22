import Foundation
import Combine

final class LicenseManager: ObservableObject {
    @Published private(set) var isPaid: Bool = false
    @Published private(set) var licenseKey: String?

    func validateLicense() async {
        isPaid = false
    }

    func activateLicense(key: String) async -> Bool {
        return false
    }

    func deactivateLicense() {
        isPaid = false
        licenseKey = nil
    }
}
