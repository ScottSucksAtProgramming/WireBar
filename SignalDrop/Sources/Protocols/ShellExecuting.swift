import Foundation

protocol ShellExecuting {
    func execute(command: String, arguments: [String]) async throws -> ShellResult
}

struct ShellResult: Sendable {
    let output: String
    let exitCode: Int32
}
