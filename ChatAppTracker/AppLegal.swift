//
//  AppLegal.swift
//  ChatAppTracker
//

import Foundation

enum AppLegal {
    static let privacyPolicyURL = URL(string: "https://www.pushthebuttonproductions.com/Privacy-Policy")!
    static let termsOfUseURL = URL(string: "https://www.pushthebuttonproductions.com/Terms-of-Use")!

    static let supportEmail = "victor@pushthebuttonproductions.com"

    static var supportMailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "ChatAppTracker Support"),
        ]
        return components.url!
    }
}
