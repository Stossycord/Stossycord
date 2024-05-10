//
//  WebView.swift
//  Stossy11DIscord
//
//  Created by Hristos Sfikas on 9/5/2024.
//

import SwiftUI
import KeychainSwift
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    public var loggedin = false

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        public var loggedin = false
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.absoluteString == "https://discord.com/api/v9/auth/mfa/totp" {
                let headers = navigationAction.request.allHTTPHeaderFields
                let token = headers?["Authorization"]
                print("Headers: \(headers)")
                print("Token: \(token ?? "none")")
                self.loggedin = true
            }
            decisionHandler(.allow)
        }
    }
}

