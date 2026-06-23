import Foundation
@testable import SignalDrop

final class MockVPNCommandExecutor: VPNCommandExecuting, @unchecked Sendable {
    var results: [String: ShellResult] = [:]
    var executedCommands: [(path: String, args: [String])] = []
    var shouldThrow: Bool = false

    func execute(executablePath: String, arguments: [String]) async throws -> ShellResult {
        executedCommands.append((path: executablePath, args: arguments))
        if shouldThrow {
            throw NSError(domain: "MockVPNCommandExecutor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return results[executablePath] ?? ShellResult(output: "", exitCode: 1)
    }
}
