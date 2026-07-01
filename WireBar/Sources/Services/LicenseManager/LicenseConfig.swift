import Foundation
import IOKit

enum LicenseConfig {
    static let checkoutURL = URL(string: "https://wirebar.lemonsqueezy.com/buy")!
    static let keychainServiceName = "com.wirebar.license"
    static let gracePeriodDays: Int = 7

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
