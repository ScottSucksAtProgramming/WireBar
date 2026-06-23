import Foundation
import ServiceManagement

final class PrivilegedHelperManager: ObservableObject, @unchecked Sendable {
    enum HelperStatus: Sendable, Equatable {
        case notInstalled
        case installed
        case requiresUpdate
        case unknown
    }

    @Published private(set) var status: HelperStatus = .unknown

    @available(macOS 13.0, *)
    func checkStatus() {
        let service = SMAppService.daemon(plistName: "\(HelperConstants.helperBundleID).plist")
        switch service.status {
        case .enabled:
            status = .installed
        case .notRegistered, .notFound:
            status = .notInstalled
        case .requiresApproval:
            status = .requiresUpdate
        @unknown default:
            status = .unknown
        }
    }

    @available(macOS 13.0, *)
    func install() throws {
        let service = SMAppService.daemon(plistName: "\(HelperConstants.helperBundleID).plist")
        try service.register()
        status = .installed
    }

    @available(macOS 13.0, *)
    func uninstall() throws {
        let service = SMAppService.daemon(plistName: "\(HelperConstants.helperBundleID).plist")
        try service.unregister()
        status = .notInstalled
    }

    func executeElevatedCommand(executablePath: String, arguments: [String]) async throws -> ShellResult {
        guard HelperConstants.isCommandAllowed(executablePath) else {
            throw NSError(
                domain: "PrivilegedHelper",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Command not in whitelist: \(executablePath)"]
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedHelperXPCProtocol.self)
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as! PrivilegedHelperXPCProtocol

            proxy.executeCommand(executablePath: executablePath, arguments: arguments) { output, exitCode, errorMessage in
                connection.invalidate()
                if let errorMessage {
                    continuation.resume(throwing: NSError(
                        domain: "PrivilegedHelper",
                        code: Int(exitCode),
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    ))
                } else {
                    continuation.resume(returning: ShellResult(output: output, exitCode: exitCode))
                }
            }
        }
    }
}
