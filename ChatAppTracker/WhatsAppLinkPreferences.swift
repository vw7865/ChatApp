//
//  WhatsAppLinkPreferences.swift
//  ChatAppTracker
//

import Foundation

/// UserDefaults / `@AppStorage` key for WhatsApp Web linked-device session (UI gating until a real session backend exists).
enum WhatsAppLinkPreferences {
    static let linkedStorageKey = "whatsappLinkedDeviceSession"
}
