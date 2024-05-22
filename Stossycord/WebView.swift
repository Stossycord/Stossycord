//
//  WebView.swift
//  Stossy11DIscord
//
//  Created by Hristos Sfikas on 9/5/2024.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: URL(string: self.url)!)
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.request.httpMethod == "POST" {
                if let httpBody = navigationAction.request.httpBody {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: httpBody, options: []) as? [String: Any] {
                            if let token = json["token"] as? String {
                                print("Token: \(token)")
                                // Save the token as needed
                            }
                        }
                    } catch {
                        print("Error parsing JSON: \(error)")
                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}
