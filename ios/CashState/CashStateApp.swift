//
//  CashStateApp.swift
//  CashState
//
//  Created by Brandon Ngacho on 2/9/26.
//

import SwiftUI
import ConvexMobile
import ClerkKit

@MainActor
let convexClient = ConvexClient(deploymentUrl: Config.convexURL)

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct CashStateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    init() {
        Clerk.configure(publishableKey: Config.clerkPublishableKey)
    }

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Clerk.shared)
                .preferredColorScheme(selectedAppearance.colorScheme)
        }
    }
}
