//
//  BackendAPIClient.swift
//  ChatAppTracker
//

import Foundation
import OSLog

/// Minimal JSON client for **your** HTTPS API. Replace paths/payloads to match your server contract.
actor BackendAPIClient {
    static let shared = BackendAPIClient()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ChatAppTracker", category: "BackendAPI")

    private init() {}

    struct CreatedInstance {
        let id: String
        let qrCodeDataURL: String
        let status: String?
    }

    struct InstanceStatus {
        let isLinked: Bool
        let status: String?
    }

    /// `POST {base}/v1/devices/apns` — adjust path and body to your backend.
    func registerAPNsDeviceToken(_ tokenHex: String) async throws {
        guard let base = BackendConfiguration.apiBaseURL else {
            throw BackendAPIError.noBaseURLConfigured
        }
        let url = base.appendingPathComponent("v1/devices/apns")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt = KeychainTokenStore.readAccessToken() {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let body = APNsRegisterBody(apnsDeviceToken: tokenHex, platform: "ios", appVersion: version)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw BackendAPIError.httpStatus(http.statusCode)
        }
    }

    func createCompanionInstance(name: String) async throws -> CreatedInstance {
        guard let base = BackendConfiguration.apiBaseURL else { throw BackendAPIError.noBaseURLConfigured }
        guard let apiKey = BackendConfiguration.apiKey else { throw BackendAPIError.noAPIKeyConfigured }

        let url = base.appendingPathComponent("instances/create")
        let startedAt = ContinuousClock.now
        logger.info("createCompanionInstance started: \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(CreateInstanceRequest(name: name))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw BackendAPIError.httpStatus(http.statusCode) }
        let elapsed = startedAt.duration(to: .now)
        logger.info("createCompanionInstance success: status=\(http.statusCode) bytes=\(data.count) elapsed=\(String(describing: elapsed), privacy: .public)")

        let decoded = try JSONDecoder().decode(CreateInstanceResponse.self, from: data)
        return CreatedInstance(id: decoded.instance.id, qrCodeDataURL: decoded.qrCode, status: decoded.instance.status)
    }

    func fetchCompanionInstanceStatus(instanceId: String) async throws -> InstanceStatus {
        guard let base = BackendConfiguration.apiBaseURL else { throw BackendAPIError.noBaseURLConfigured }
        guard let apiKey = BackendConfiguration.apiKey else { throw BackendAPIError.noAPIKeyConfigured }

        let url = base.appendingPathComponent("instances/\(instanceId)/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw BackendAPIError.httpStatus(http.statusCode) }
        logger.debug("fetchCompanionInstanceStatus ok: instance=\(instanceId, privacy: .public) statusCode=\(http.statusCode) bytes=\(data.count)")

        let decoded = try JSONDecoder().decode(InstanceStatusResponse.self, from: data)
        let state = decoded.state?.lowercased() ?? decoded.status?.lowercased() ?? ""
        let linked = decoded.linked ?? decoded.isLinked ?? decoded.connected ?? (state == "linked" || state == "connected" || state == "online")
        return InstanceStatus(isLinked: linked, status: decoded.state ?? decoded.status)
    }
}

private struct APNsRegisterBody: Encodable {
    let apnsDeviceToken: String
    let platform: String
    let appVersion: String
}

private struct CreateInstanceRequest: Encodable {
    let name: String
}

private struct CreateInstanceResponse: Decodable {
    struct Instance: Decodable {
        let id: String
        let status: String?
    }

    let instance: Instance
    let qrCode: String
}

private struct InstanceStatusResponse: Decodable {
    let linked: Bool?
    let isLinked: Bool?
    let connected: Bool?
    let state: String?
    let status: String?
}

enum BackendAPIError: Error {
    case noBaseURLConfigured
    case noAPIKeyConfigured
    case invalidResponse
    case httpStatus(Int)
    case invalidQRCodeData
}
