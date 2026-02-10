import Foundation

/// App configuration - UPDATE THESE VALUES
enum Config {
    // MARK: - Backend (ngrok)

    /// Your ngrok URL - UPDATE THIS!
    /// Example: "https://abc123.ngrok.io"
    static let backendURL = "https://b163-136-27-22-198.ngrok-free.app"

    /// API version prefix
    static let apiVersion = "/app/v1"

    /// Full API base URL
    static var apiBaseURL: String {
        backendURL + apiVersion
    }

    // MARK: - Supabase

    /// Supabase project URL
    static let supabaseURL = "https://qdilsbsgdssmwbmtoxdf.supabase.co"

    /// Supabase anon key (public, safe to embed)
    static let supabasePublishableKey = "sb_publishable_Fp-QAXA1hicpWDDVj4b0wg_U5i-1f8d"

    // MARK: - App

    static let debugMode = true
    static let requestTimeout: TimeInterval = 30
}
