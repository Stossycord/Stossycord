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
        let webView = WKWebView()
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"

        webView.navigationDelegate = context.coordinator

        // Load the Discord login page
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

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
              const iframe = document.createElement("iframe");
              return document.body.appendChild(iframe).contentWindow.localStorage.token;
            })();
            """

            // Execute JavaScript and retry if not found
            webView.evaluateJavaScript(js) { result, error in
                if let token = result as? String, !token.isEmpty {
                    let cool = token.replacingOccurrences(of: "\"", with: "")
                    self.onTokenDetected?(cool)
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
#endif

