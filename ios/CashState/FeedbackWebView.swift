import SwiftUI
import WebKit

struct FeedbackWebView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            WebView(url: URL(string: Config.feedbackURL)!)
                .navigationTitle("Feedback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
