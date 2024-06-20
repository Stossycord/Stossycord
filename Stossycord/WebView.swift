//
//  WebView.swift
//  Stossy11DIscord
//
//  Created by Stossy11 on 9/5/2024.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let captchaSiteKey: String
    let captchaService: String

    func makeUIView(context: Context) -> WKWebView {
        let wkWebView = WKWebView()
        wkWebView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://\(captchaService).com/\(captchaSiteKey)") {
            let request = URLRequest(url: url)
            wkWebView.load(request)
        }
        return wkWebView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update the view if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.getElementById('g-recaptcha-response').value") { (result, error) in
                if let captchaResponse = result as? String {
                    // Here you would send the `captchaResponse` back to the Discord API
                    print("CAPTCHA response: \(captchaResponse)")
                }
            }
        }
    }
}
