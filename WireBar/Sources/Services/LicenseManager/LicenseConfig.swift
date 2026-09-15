import Foundation
import IOKit
import CryptoKit

enum LicenseConfig {
    static let checkoutURL = URL(string: "https://wirebar.lemonsqueezy.com/buy")!
    static let keychainServiceName = "com.wirebar.license"
    static let gracePeriodDays: Int = 7

    /// Public half of the beta key signing key. The private half is at ~/.wirebar/beta-signing-key,
    /// never in the repo. Temporary: remove with BetaLicenseKey before the paid launch.
    static var betaPublicKey: Curve25519.Signing.PublicKey {
        try! Curve25519.Signing.PublicKey(
            rawRepresentation: Data(base64Encoded: "EXtnI+nJw1z69yit+6Hm9VQAki+vzivN01Ly7lYPTTA=")!
        )
    }

    /// Returns the hardware UUID of this Mac, used as the instance name for license activation.
    static var hardwareUUID: String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        guard service != IO_OBJECT_NULL,
              let uuidData = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0),
              let uuid = uuidData.takeRetainedValue() as? String
        else {
            return ProcessInfo.processInfo.hostName
        }
        return uuid
    }
}
