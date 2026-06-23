import Foundation

enum HelperConstants {
    static let helperBundleID = "com.scottkostolni.SignalDrop.PrivilegedHelper"
    static let machServiceName = "com.scottkostolni.SignalDrop.PrivilegedHelper"

    static let allowedCommands: Set<String> = [
        "/usr/local/bin/wg-quick",
        "/opt/homebrew/bin/wg-quick"
    ]

    static func isCommandAllowed(_ executablePath: String) -> Bool {
        allowedCommands.contains(executablePath)
    }
}

@objc protocol PrivilegedHelperXPCProtocol {
    func executeCommand(executablePath: String, arguments: [String], reply: @escaping (String, Int32, String?) -> Void)
}
