import Foundation

protocol VPNCommandExecuting: Sendable {
    func execute(executablePath: String, arguments: [String]) async throws -> ShellResult
}
