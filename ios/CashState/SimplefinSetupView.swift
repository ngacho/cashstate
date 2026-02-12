import SwiftUI

struct SimplefinSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var setupToken = ""
    @State private var institutionName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let apiClient: APIClient
    let onSuccess: (String) -> Void  // Pass item_id to trigger sync

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Setup Instructions")
                        .font(.headline)
                    Text("1. Go to SimpleFin and connect all your bank accounts\n2. Generate a setup token\n3. Paste it below to sync all your transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                Section("Setup Token") {
                    TextField("Paste your SimpleFin token here", text: $setupToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }

                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: setupSimplefin) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Connect")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(setupToken.isEmpty || isLoading)
                }
            }
            .navigationTitle("Connect SimpleFin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func setupSimplefin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await apiClient.setupSimplefin(
                    setupToken: setupToken,
                    institutionName: institutionName.isEmpty ? nil : institutionName
                )

                await MainActor.run {
                    isLoading = false
                    if Config.debugMode {
                        print("✅ Account connected: \(response.itemId)")
                    }
                    // Auto-sync after successful setup
                    onSuccess(response.itemId)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let apiError = error as? APIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    if Config.debugMode {
                        print("❌ SimpleFin setup failed: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    SimplefinSetupView(
        apiClient: APIClient(),
        onSuccess: { _ in }
    )
}
