import ClerkKit
import SwiftUI

struct ProfileView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    private var hasChanges: Bool {
        let originalFirst = Clerk.shared.user?.firstName ?? ""
        let originalLast = Clerk.shared.user?.lastName ?? ""
        return firstName != originalFirst || lastName != originalLast
    }

    private var canSave: Bool {
        hasChanges
            && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Avatar + email header
                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Text(initials)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Theme.Colors.primary)
                    }

                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.lg)

                // Editable name fields
                VStack(spacing: 0) {
                    editableRow(label: "First Name", text: $firstName)
                    Divider().padding(.leading, Theme.Spacing.md)
                    editableRow(label: "Last Name", text: $lastName)
                }
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(color: Theme.Colors.shadowColor, radius: 6, x: 0, y: 2)
                .padding(.horizontal, Theme.Spacing.md)

                // Save button
                Button(action: save) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canSave ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
                .disabled(!canSave)
                .padding(.horizontal, Theme.Spacing.md)

                // Delete account
                VStack(spacing: 0) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(Theme.Colors.expense)
                            Text("Delete Account")
                                .foregroundColor(Theme.Colors.expense)
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(Theme.Colors.expense)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .contentShape(Rectangle())
                    }
                    .disabled(isDeletingAccount)
                }
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(color: Theme.Colors.shadowColor, radius: 6, x: 0, y: 2)
                .padding(.horizontal, Theme.Spacing.md)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firstName = Clerk.shared.user?.firstName ?? ""
            lastName = Clerk.shared.user?.lastName ?? ""
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text(deleteErrorMessage)
        }
        .alert("Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func editableRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 100, alignment: .leading)
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
    }

    private var email: String {
        Clerk.shared.user?.primaryEmailAddress?.emailAddress ?? ""
    }

    private var initials: String {
        let first = firstName.prefix(1)
        let last = lastName.prefix(1)
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await Clerk.shared.user?.update(.init(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                ))
            } catch {
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
            isSaving = false
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                Analytics.shared.track(.userLoggedOut)
                Analytics.shared.reset()
                try await Clerk.shared.user?.delete()
            } catch {
                deleteErrorMessage = error.localizedDescription
                showDeleteError = true
            }
            isDeletingAccount = false
        }
    }
}
