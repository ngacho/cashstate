//
//  CashStateApp.swift
//  CashState
//
//  Created by Brandon Ngacho on 2/9/26.
//

import SwiftUI
import ConvexMobile
import ClerkConvex
import ClerkKit

@MainActor
let convexClient = ConvexClientWithAuth(
    deploymentUrl: Config.convexURL,
    authProvider: ClerkConvexAuthProvider()
)

@main
struct CashStateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
