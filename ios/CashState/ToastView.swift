import SwiftUI

enum ToastStyle {
    case success
    case error
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return Theme.Colors.income
        case .error: return Theme.Colors.expense
        case .info: return Theme.Colors.primary
        }
    }
}

struct Toast: Equatable {
    let style: ToastStyle
    let message: String
    var duration: Double = 3.0

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.message == rhs.message
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastBanner(toast: toast)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    self.toast = nil
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.toast = nil
                            }
                        }
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
    }
}

private struct ToastBanner: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: toast.style.icon)
                .foregroundColor(toast.style.color)
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Theme.Colors.shadowColor, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}
