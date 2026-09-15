import XCTest
import CryptoKit
@testable import WireBar

final class BetaLicenseKeyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeKey(
        name: String = "Alex",
        days: Double = 90,
        signedBy signingKey: Curve25519.Signing.PrivateKey
    ) throws -> String {
        try BetaLicenseKey.make(name: name, expiry: now.addingTimeInterval(days * 86400), privateKey: signingKey)
    }

    func testValidKeyReturnsNameAndExpiry() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let key = try makeKey(signedBy: signingKey)

        let result = BetaLicenseKey.check(key, publicKey: signingKey.publicKey, now: now)

        XCTAssertEqual(result, .valid(BetaLicenseKey(name: "Alex", expiry: now.addingTimeInterval(90 * 86400))))
    }

    func testKeyWithSurroundingWhitespaceIsAccepted() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let key = try makeKey(signedBy: signingKey)

        let result = BetaLicenseKey.check("  \(key)\n", publicKey: signingKey.publicKey, now: now)

        guard case .valid = result else { return XCTFail("Expected valid, got \(result)") }
    }

    func testKeyPastItsEndDateIsExpired() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let key = try makeKey(days: 90, signedBy: signingKey)

        let result = BetaLicenseKey.check(key, publicKey: signingKey.publicKey, now: now.addingTimeInterval(91 * 86400))

        guard case .expired = result else { return XCTFail("Expected expired, got \(result)") }
    }

    func testKeySignedBySomeoneElseIsInvalid() throws {
        let key = try makeKey(signedBy: Curve25519.Signing.PrivateKey())

        let result = BetaLicenseKey.check(key, publicKey: Curve25519.Signing.PrivateKey().publicKey, now: now)

        XCTAssertEqual(result, .invalid)
    }

    func testEditedNameOrDateIsInvalid() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let alexKey = try makeKey(name: "Alex", days: 90, signedBy: signingKey)
        let longerKey = try makeKey(name: "Alex", days: 900, signedBy: signingKey)

        // Longer key's contents with the 90-day key's signature.
        let payload = longerKey.split(separator: ".")[0]
        let signature = alexKey.split(separator: ".")[1]
        let forged = "\(payload).\(signature)"

        XCTAssertEqual(BetaLicenseKey.check(forged, publicKey: signingKey.publicKey, now: now), .invalid)
    }

    func testGarbageIsInvalid() {
        let publicKey = Curve25519.Signing.PrivateKey().publicKey

        for key in ["", "WBETA-", "WBETA-nope", "WBETA-abc.def", "ABCD-1234-EFGH"] {
            XCTAssertEqual(BetaLicenseKey.check(key, publicKey: publicKey, now: now), .invalid, "\(key)")
        }
    }

    func testRecognizesBetaKeysByPrefix() {
        XCTAssertTrue(BetaLicenseKey.isBetaKey("WBETA-abc.def"))
        XCTAssertTrue(BetaLicenseKey.isBetaKey("  WBETA-abc.def"))
        XCTAssertFalse(BetaLicenseKey.isBetaKey("ABCD-1234-EFGH"))
    }
}
