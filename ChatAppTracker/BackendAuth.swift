//
//  BackendAuth.swift
//  ChatAppTracker
//

import Foundation

/// Call after your login/sign-in API returns a bearer token for **your** backend.
enum BackendAuth {
    static func setAccessToken(_ token: String) throws {
        try KeychainTokenStore.saveAccessToken(token)
        PushDeviceRegistrar.markNeedsUpload()
    }

    static func clearAccessToken() throws {
        try KeychainTokenStore.deleteAccessToken()
        PushDeviceRegistrar.markNeedsUpload()
    }
}
