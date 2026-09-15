import Foundation
import CryptoKit

/// A temporary beta access key: a tester's name and end date, signed with the developer's
/// private key (made by `scripts/make-beta-key.swift`). The app holds only the public key,
/// so it can check keys but not make them. Remove before the paid launch.
///
/// Format: `WBETA-<base64url("name|expiryUnixSeconds")>.<base64url(Ed25519 signature)>`
struct BetaLicenseKey: Equatable, Sendable {
    let name: String
    let expiry: Date

    enum Check: Equatable, Sendable {
        case valid(BetaLicenseKey)
        case expired(BetaLicenseKey)
        case invalid
    }

    static let prefix = "WBETA-"

    static func isBetaKey(_ key: String) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix)
    }

    static func check(_ key: String, publicKey: Curve25519.Signing.PublicKey, now: Date) -> Check {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return .invalid }

        let parts = trimmed.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payload = decodeBase64URL(parts[0]),
              let signature = decodeBase64URL(parts[1]),
              publicKey.isValidSignature(signature, for: payload),
              let text = String(data: payload, encoding: .utf8),
              let separator = text.lastIndex(of: "|"),
              let seconds = TimeInterval(text[text.index(after: separator)...])
        else { return .invalid }

        let betaKey = BetaLicenseKey(name: String(text[..<separator]), expiry: Date(timeIntervalSince1970: seconds))
        return now < betaKey.expiry ? .valid(betaKey) : .expired(betaKey)
    }

    static func make(name: String, expiry: Date, privateKey: Curve25519.Signing.PrivateKey) throws -> String {
        let payload = Data("\(name)|\(Int(expiry.timeIntervalSince1970))".utf8)
        let signature = try privateKey.signature(for: payload)
        return prefix + encodeBase64URL(payload) + "." + encodeBase64URL(signature)
    }

    private static func encodeBase64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeBase64URL(_ text: Substring) -> Data? {
        var base64 = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
