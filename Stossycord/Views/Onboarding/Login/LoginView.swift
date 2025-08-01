//
//  LoginView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift
import WebKit

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @State var login = false
    @State var token = ""
    @StateObject var webSocketService: WebSocketService
    let keychain = KeychainSwift()
    var body: some View {
        VStack {
            Text("Login")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
            
            WebView(url: URL(string: "https://discord.com/login")!) { newToken in
                self.token = newToken
                print(newToken)
                keychain.set(token, forKey: "token")
                
                if !token.isEmpty {
                    dismiss()
                    webSocketService.connect()
                }
                
            }
            .frame(width: 900)
            
            .interactiveDismissDisabled()
            TextField("Discord Token", text: $token)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onSubmit {
                    keychain.set(token, forKey: "token")
                    
                    if !token.isEmpty {
                        dismiss()
                        webSocketService.connect()
                    }
                }
                .padding(.horizontal)
        }
        .padding()
    }
}





#if os(macOS)
struct WebView: NSViewRepresentable {
    let url: URL
    var onTokenDetected: ((String) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Load the Discord login page
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        return Coordinator(onTokenDetected: onTokenDetected)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTokenDetected: ((String) -> Void)?
        var retryCount = 0

        init(onTokenDetected: ((String) -> Void)?) {
            self.onTokenDetected = onTokenDetected
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkForToken(in: webView)
        }

        func checkForToken(in webView: WKWebView) {
            // JavaScript to retrieve token from localStorage
            let js = """
            (function() {
              let a = [];
              webpackChunkdiscord_app.push([[0],,e=>Object.keys(e.c).find(t=>(t=e(t)?.default?.getToken?.())&&a.push(t))]);
              return a[0];
            })();
            """

            // Execute JavaScript and retry if not found
            webView.evaluateJavaScript(js) { result, error in
                if let token = result as? String, !token.isEmpty {
                    self.onTokenDetected?(token)
                } else {
                    self.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self.checkForToken(in: webView)
                    }
                }
            }
        }
    }
}

#else
struct WebView: UIViewRepresentable {
    let url: URL
    var onTokenDetected: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(url: url)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onTokenDetected: onTokenDetected)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var onTokenDetected: ((String) -> Void)?
        weak var webView: WKWebView?
        var retryCount = 0
        private var hasSetInitialUserAgent = false
        
        init(onTokenDetected: ((String) -> Void)?) {
            self.onTokenDetected = onTokenDetected
        }
        
        func load(url: URL) {
            guard let webView = webView else { return }
            
            let isLoginPage = url.absoluteString.starts(with: "https://discord.com/login")
            let userAgent: String? = isLoginPage
                ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
                : nil //"Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"
            
            webView.customUserAgent = userAgent
            hasSetInitialUserAgent = true
            
            webView.evaluateJavaScript("navigator.userAgent") { result, error in
                if let userAgent = result as? String {
                    print("User Agent: \(userAgent)")
                } else if let error = error {
                    print("Failed to get user agent: \(error)")
                }
            }
            
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkForToken(in: webView)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            if hasSetInitialUserAgent && navigationAction.navigationType != .other {
                let isLoginPage = url.absoluteString.starts(with: "https://discord.com/login")
                let userAgent: String? = isLoginPage
                    ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
                    : nil //"Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"
                
                // Only reload if user agent needs to change
                if webView.customUserAgent != userAgent {
                    webView.customUserAgent = userAgent
                    let request = URLRequest(url: url)
                    webView.evaluateJavaScript("navigator.userAgent") { result, error in
                        if let userAgent = result as? String {
                            print("User Agent: \(userAgent)")
                        } else if let error = error {
                            print("Failed to get user agent: \(error)")
                        }
                    }
                    webView.load(request)
                    decisionHandler(.cancel)
                    return
                }
            }
            
            decisionHandler(.allow)
        }
        
        func checkForToken(in webView: WKWebView) {
            let js = """
            (function() {
              const iframe = document.createElement("iframe");
              return document.body.appendChild(iframe).contentWindow.localStorage.token;
            })();
            """
            
            webView.evaluateJavaScript(js) { result, error in
                if let token = result as? String, !token.isEmpty {
                    let strippedToken = token.replacingOccurrences(of: "\"", with: "")
                    self.onTokenDetected?(strippedToken)
                } else {
                    self.retryCount += 1
                    if self.retryCount < 25 { // Add a retry limit
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.checkForToken(in: webView)
                        }
                    }
                }
            }
        }
    }
}
#endif

