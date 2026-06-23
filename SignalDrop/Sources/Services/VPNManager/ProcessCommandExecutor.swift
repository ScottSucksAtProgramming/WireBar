import Foundation

final class ProcessCommandExecutor: VPNCommandExecuting, @unchecked Sendable {
    func execute(executablePath: String, arguments: [String]) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(output: output, exitCode: process.terminationStatus))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
