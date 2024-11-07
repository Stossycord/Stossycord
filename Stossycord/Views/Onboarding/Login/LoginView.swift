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
                
                keychain.set(token, forKey: "token")
                
                if !token.isEmpty {
                    dismiss()
                    webSocketService.connect()
                }
                
            }
            .interactiveDismissDisabled()
            /*
             TextField("Discord Token", text: $token)
             .padding()
             .background(
             RoundedRectangle(cornerRadius: 10)
             .fill(Color(UIColor.systemGray5))
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
             */
        }
    }
}




struct WebView: UIViewRepresentable {
    let url: URL
    var onTokenDetected: ((String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
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
              let a = [];
              webpackChunkdiscord_app.push([[0],,e=>Object.keys(e.c).find(t=>(t=e(t)?.default?.getToken?.())&&a.push(t))]);
              return a[0];
            })();
            """

            // Execute JavaScript and retry if not found
            webView.evaluateJavaScript(js) { result, error in
                if let token = result as? String {
                    self.onTokenDetected?(token)
                } else {
                    self.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.checkForToken(in: webView)
                    }
                }
            }
        }
    }
}
    

