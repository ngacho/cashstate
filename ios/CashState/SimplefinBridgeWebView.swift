import SwiftUI
import WebKit

struct SimplefinBridgeWebView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            WebView(url: URL(string: "https://beta-bridge.simplefin.org/")!)
                .navigationTitle("SimpleFin")
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
