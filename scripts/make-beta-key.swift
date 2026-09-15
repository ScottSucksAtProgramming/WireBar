#!/usr/bin/env swift
// Makes a WireBar beta license key. Temporary: remove along with BetaLicenseKey before the paid launch.
//
// Usage:  swift scripts/make-beta-key.swift "Tester Name" [days, default 90]
//
// The signing key lives at ~/.wirebar/beta-signing-key, outside the repo (the repo is public).
// The first run creates it and prints the public key for LicenseConfig.betaPublicKeyBase64.
// Back that file up: without it you can't make new keys (keys already sent keep working).
//
// The key format must match BetaLicenseKey.make in
// WireBar/Sources/Services/LicenseManager/BetaLicenseKey.swift.

import CryptoKit
import Foundation

let keyURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".wirebar/beta-signing-key")
let arguments = CommandLine.arguments.dropFirst()

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let privateKey: Curve25519.Signing.PrivateKey
if let raw = try? Data(contentsOf: keyURL) {
    privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
} else {
    privateKey = Curve25519.Signing.PrivateKey()
    try FileManager.default.createDirectory(
        at: keyURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    try privateKey.rawRepresentation.write(to: keyURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    print("Created signing key at \(keyURL.path). Back it up somewhere safe.")
    print("Public key for LicenseConfig.betaPublicKeyBase64: \(privateKey.publicKey.rawRepresentation.base64EncodedString())")
}

guard let name = arguments.first?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
    print("Usage: swift scripts/make-beta-key.swift \"Tester Name\" [days]")
    exit(1)
}

let days = arguments.dropFirst().first.flatMap(Int.init) ?? 90
let expiry = Int(Date().addingTimeInterval(TimeInterval(days * 86400)).timeIntervalSince1970)
let payload = Data("\(name)|\(expiry)".utf8)
let signature = try privateKey.signature(for: payload)
let endDate = Date(timeIntervalSince1970: TimeInterval(expiry)).formatted(date: .long, time: .omitted)

print("Beta key for \(name), ends \(endDate):")
print("WBETA-\(base64URL(payload)).\(base64URL(signature))")
