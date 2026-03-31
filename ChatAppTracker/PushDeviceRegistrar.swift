//
//  PushDeviceRegistrar.swift
//  ChatAppTracker
//

import Foundation
import UIKit

extension Notification.Name {
    /// Posted when a remote notification arrives (foreground/background). `userInfo` is the APNs payload.
    static let appDidReceiveRemoteNotification = Notification.Name("appDidReceiveRemoteNotification")
}

/// Converts the APNs device token and uploads it to your backend when `APIBaseURL` is set.
enum PushDeviceRegistrar {
    private static let uploadedTokenKey = "lastUploadedAPNsTokenHex"

    static func storeAndUpload(deviceToken: Data) async {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "lastAPNsDeviceTokenHex")

        guard BackendConfiguration.apiBaseURL != nil else { return }

        if UserDefaults.standard.string(forKey: uploadedTokenKey) == hex {
            return
        }

        do {
            try await BackendAPIClient.shared.registerAPNsDeviceToken(hex)
            UserDefaults.standard.set(hex, forKey: uploadedTokenKey)
        } catch {
            // Retry on next launch or token refresh; avoid tight loops.
        }
    }

    /// Call after login or when you need to re-register (e.g. new bearer token).
    static func markNeedsUpload() {
        UserDefaults.standard.removeObject(forKey: uploadedTokenKey)
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
