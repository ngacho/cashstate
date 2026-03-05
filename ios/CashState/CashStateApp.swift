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

@main
struct CashStateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        Clerk.configure(publishableKey: Config.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
