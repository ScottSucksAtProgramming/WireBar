import Foundation

@objc protocol PrivilegedHelperXPCProtocol {
    func executeCommand(executablePath: String, arguments: [String], reply: @escaping (String, Int32, String?) -> Void)
}

class HelperTool: NSObject, NSXPCListenerDelegate, PrivilegedHelperXPCProtocol {
    private let listener: NSXPCListener

    private let allowedCommands: Set<String> = [
        "/usr/local/bin/wg-quick",
        "/opt/homebrew/bin/wg-quick"
    ]

    override init() {
        listener = NSXPCListener(machServiceName: "com.scottkostolni.SignalDrop.PrivilegedHelper")
        super.init()
        listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(
            nil,
            [kSecGuestAttributePid: pid as CFNumber] as CFDictionary,
            [],
            &code
        ) == errSecSuccess, let secCode = code else {
            return false
        }

        let requirement = "anchor apple generic and identifier \"com.scottkostolni.SignalDrop\" and certificate leaf[subject.OU] = \"5N69HV7X7S\""
        var requirementRef: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &requirementRef) == errSecSuccess,
              let req = requirementRef,
              SecCodeCheckValidity(secCode, [], req) == errSecSuccess else {
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: PrivilegedHelperXPCProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func executeCommand(executablePath: String, arguments: [String], reply: @escaping (String, Int32, String?) -> Void) {
        guard allowedCommands.contains(executablePath) else {
            reply("", -1, "Command not in whitelist")
            return
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            reply("", -1, "Executable not found at \(executablePath)")
            return
        }

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
            reply(output, process.terminationStatus, nil)
        } catch {
            reply("", -1, error.localizedDescription)
        }
    }
}

let tool = HelperTool()
tool.run()
