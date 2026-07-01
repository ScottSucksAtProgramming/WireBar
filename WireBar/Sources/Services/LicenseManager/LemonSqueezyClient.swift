import Foundation

struct LemonSqueezyClient: LicenseValidating, Sendable {
    private let baseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func activate(licenseKey: String, instanceName: String) async throws -> LicenseActivationResult {
        let body = "license_key=\(encode(licenseKey))&instance_name=\(encode(instanceName))"
        let data = try await post(endpoint: "activate", body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseAPIError.unexpectedResponse("Invalid JSON")
        }

        if let error = json["error"] as? String {
            if error.localizedCaseInsensitiveContains("invalid") || error.localizedCaseInsensitiveContains("not found") {
                throw LicenseAPIError.invalidKey
            }
            if error.localizedCaseInsensitiveContains("limit") {
                throw LicenseAPIError.activationLimitReached
            }
            throw LicenseAPIError.unexpectedResponse(error)
        }

        guard let meta = json["meta"] as? [String: Any],
              let instanceId = meta["instance_id"] as? String,
              let licenseKeyData = json["license_key"] as? [String: Any],
              let status = licenseKeyData["status"] as? String,
              let limit = licenseKeyData["activation_limit"] as? Int,
              let usage = licenseKeyData["activation_usage"] as? Int
        else {
            throw LicenseAPIError.unexpectedResponse("Missing expected fields")
        }

        return LicenseActivationResult(
            instanceId: instanceId,
            licenseKeyStatus: status,
            activationLimit: limit,
            activationUsage: usage
        )
    }

    func validate(licenseKey: String, instanceId: String) async throws -> LicenseValidationResult {
        let body = "license_key=\(encode(licenseKey))&instance_id=\(encode(instanceId))"
        let data = try await post(endpoint: "validate", body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseAPIError.unexpectedResponse("Invalid JSON")
        }

        let valid = json["valid"] as? Bool ?? false
        let licenseKeyData = json["license_key"] as? [String: Any]
        let status = licenseKeyData?["status"] as? String ?? "unknown"

        return LicenseValidationResult(valid: valid, licenseKeyStatus: status)
    }

    func deactivate(licenseKey: String, instanceId: String) async throws -> LicenseDeactivationResult {
        let body = "license_key=\(encode(licenseKey))&instance_id=\(encode(instanceId))"
        let data = try await post(endpoint: "deactivate", body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseAPIError.unexpectedResponse("Invalid JSON")
        }

        let deactivated = json["deactivated"] as? Bool ?? false
        return LicenseDeactivationResult(deactivated: deactivated)
    }

    // MARK: - Helpers

    private func post(endpoint: String, body: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseAPIError.unexpectedResponse("Non-HTTP response")
        }

        // LemonSqueezy returns 400 for invalid keys, 200 for success
        // Both have JSON bodies we need to parse, so only fail on server errors
        if httpResponse.statusCode >= 500 {
            throw LicenseAPIError.networkError("Server error: \(httpResponse.statusCode)")
        }

        return data
    }

    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
