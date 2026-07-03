//
//  LoginView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift
import WebKit
import Vision

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var webSocketService: WebSocketService
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var mfaCode = ""
    @State private var qrCodeImage: UIImage? = nil
    
    let keychain = KeychainSwift()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
            
            switch authService.state {
                
            case .needsCaptcha(let sitekey):
                VStack(spacing: 12) {
                    Text("Complete Captcha")
                        .font(.headline)
                    
                    HCaptchaWebView(sitekey: sitekey) { token in
                        Task {
                            await authService.retryWithCaptcha(token: token)
                        }
                    }
                    .frame(height: 600)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    
                    Button("Cancel") {
                        authService.state = .idle
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
                
            case .needsMFA(let challenge):
                VStack(spacing: 16) {
                    Text("Two-Factor Authentication")
                        .font(.headline)
                    
                    if challenge.hasUnsupportedPasskey {
                        Text(challenge.unsupportedPasskeyMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if challenge.supportsCode {
                        TextField("Authenticator or backup code", text: $mfaCode)
                            .keyboardType(.asciiCapable)
                            .textContentType(.oneTimeCode)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button(action: {
                            let code = mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task { await authService.submitMFA(code: code, ticket: challenge.ticket) }
                        }) {
                            Text("Verify Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                )
                        }
                        .disabled(mfaCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    Button("Cancel") {
                        authService.state = .idle
                        mfaCode = ""
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
                
            case .loading:
                credentialFields
                ProgressView("Logging in...")
                
            default:
                if let qr = qrCodeImage {
                    VStack(spacing: 16) {
                        Text("Scan QR Code")
                            .font(.headline)
                        
                        Image(uiImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                        
                        Text("Or login with email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                credentialFields
                
                if case .failure(let msg) = authService.state {
                    Text(msg)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding()
        .interactiveDismissDisabled()
        .onChange(of: authService.state) { newState in
            if case .success(let token) = newState {
                keychain.set(token, forKey: "token")
                dismiss()
                webSocketService.connect()
            }
        }
    }
    
    
    private var credentialFields: some View {
        VStack(spacing: 16) {
            TextField("Email or Phone Number", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Button(action: {
                let e = email, p = password
                Task { await authService.login(email: e, password: p) }
            }) {
                Text("Log In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                    )
            }
            .disabled(email.isEmpty || password.isEmpty)
        }
        .padding(.horizontal)
    }
}

struct HCaptchaWebView: UIViewRepresentable {
    let sitekey: String
    var onTokenReceived: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTokenReceived: onTokenReceived)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "hcaptcha")
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        
        let html = makeCaptchaHTML(sitekey: sitekey)
        webView.loadHTMLString(html, baseURL: URL(string: "https://discord.com"))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    private func makeCaptchaHTML(sitekey: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
            <style>
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background: transparent;
                }
            </style>
        </head>
        <body>
            <div class="h-captcha"
                 data-sitekey="\(sitekey)"
                 data-callback="onCaptchaSolved"
                 data-theme="dark">
            </div>
            <script>
                function onCaptchaSolved(token) {
                    window.webkit.messageHandlers.hcaptcha.postMessage(token);
                }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onTokenReceived: (String) -> Void
        
        init(onTokenReceived: @escaping (String) -> Void) {
            self.onTokenReceived = onTokenReceived
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "hcaptcha",
                  let token = message.body as? String,
                  !token.isEmpty else { return }
            Task { @MainActor in
                self.onTokenReceived(token)
            }
        }
    }
}

extension UIImage {
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        let clamped = CGRect(
            x: max(0, min(rect.origin.x, CGFloat(cgImage.width))),
            y: max(0, min(rect.origin.y, CGFloat(cgImage.height))),
            width: max(0, min(rect.width, CGFloat(cgImage.width) - rect.origin.x)),
            height: max(0, min(rect.height, CGFloat(cgImage.height) - rect.origin.y))
        )
        
        guard clamped.width > 0, clamped.height > 0,
              let cropped = cgImage.cropping(to: clamped) else { return nil }
        
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
