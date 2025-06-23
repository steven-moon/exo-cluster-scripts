import SwiftUI
import WebKit

struct ExoWebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ExoWebView
        
        init(_ parent: ExoWebView) {
            self.parent = parent
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView loaded successfully")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
        
        // MARK: - WKUIDelegate
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle new window requests by opening in default browser
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Exo Chat"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Exo Chat"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }
    }
}

struct ExoChatView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Exo Chat Interface...")
                        .font(.headline)
                    Text("This may take a moment if the service is starting up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Unable to Load Chat Interface")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        checkServiceAndLoad()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ExoWebView(url: URL(string: "http://localhost:52415")!)
            }
        }
        .onAppear {
            checkServiceAndLoad()
        }
    }
    
    private func checkServiceAndLoad() {
        isLoading = true
        errorMessage = nil
        
        // Check if exo service is accessible
        let url = URL(string: "http://localhost:52415")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Connection failed: \(error.localizedDescription)\n\nMake sure the Exo service is running."
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                        // Service is accessible
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Service returned status code: \(httpResponse.statusCode)"
                    }
                } else {
                    self.errorMessage = "Unknown error occurred"
                }
            }
        }
        
        task.resume()
    }
}

#Preview {
    ExoChatView()
} 