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
    @StateObject var webSocketService: WebSocketService
    @StateObject private var viewModel = LoginViewModel()
    
    let keychain = KeychainSwift()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
            
            if viewModel.showCaptcha || viewModel.show2FA {
                VStack(spacing: 12) {
                    if viewModel.showCaptcha {
                        Text("Complete Captcha")
                            .font(.headline)
                    } else if viewModel.show2FA {
                        Text("Complete 2FA Verification")
                            .font(.headline)
                    }
                    
                    InteractiveDiscordWebView(viewModel: viewModel)
                        .frame(height: 600)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    
                    if viewModel.isLoading {
                        ProgressView("Verifying...")
                    }
                    
                    Button("Cancel") {
                        viewModel.showCaptcha = false
                        viewModel.show2FA = false
                        viewModel.isLoading = false
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            } else {
                if let qrCodeURL = viewModel.qrCodeImage {
                    VStack(spacing: 16) {
                        Text("Scan QR Code")
                            .font(.headline)
                        
                        Image(uiImage: qrCodeURL)
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
                
                VStack(spacing: 16) {
                    TextField("Email or Phone Number", text: $viewModel.email)
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
                    
                    SecureField("Password", text: $viewModel.password)
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
                        viewModel.login()
                    }) {
                        Text("Log In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                    }
                    .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal)
            }
            
            if viewModel.isLoading && !viewModel.showCaptcha && !viewModel.show2FA {
                ProgressView("Logging in...")
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
            
        }
        .background {
            if !viewModel.showCaptcha && !viewModel.show2FA {
                VStack {
                    Spacer()
                    HiddenDiscordWebView(viewModel: viewModel)
                        .frame(width: 900)
                        .border(Color.red, width: 2)
                        .scaleEffect(0.2)
                       //  .offset(x: 10000 ,y: 10000)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .interactiveDismissDisabled()
        .onChange(of: viewModel.token) { newToken in
            if !newToken.isEmpty {
                keychain.set(newToken, forKey: "token")
                dismiss()
                webSocketService.connect()
            }
        }
        .onDisappear() {
            HiddenDiscordWebView.Coordinator.qrTimer?.invalidate()
            HiddenDiscordWebView.Coordinator.backgroundTokenTimer?.invalidate()
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var token = ""
    @Published var webView: WKWebView?
    @Published var qrCodeImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldSubmitLogin = false
    @Published var showCaptcha = false
    @Published var show2FA = false
    
    func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        shouldSubmitLogin = true
    }
}


struct InteractiveDiscordWebView: UIViewRepresentable {
    @ObservedObject var viewModel: LoginViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        let webView = viewModel.webView ?? WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        context.coordinator.viewModel = viewModel
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.startMonitoring()
    }
    
    func makeCoordinator() -> InteractiveCoordinator {
        InteractiveCoordinator()
    }
    
    class InteractiveCoordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        weak var viewModel: LoginViewModel?
        private var monitoringTimer: Timer?
        
        func startMonitoring() {
            monitoringTimer?.invalidate()
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkForToken()
            }
        }
        
        func checkForToken() {
            guard let webView = webView else { return }
            
            let js = """
            (function() {
                const iframe = document.createElement("iframe");
                return document.body.appendChild(iframe).contentWindow.localStorage.token;
            })();
            """
            
            webView.evaluateJavaScript(js) { [weak self] result, error in
                if let token = result as? String, !token.isEmpty {
                    let strippedToken = token.replacingOccurrences(of: "\"", with: "")
                    Task { @MainActor in 
                        self?.viewModel?.token = strippedToken
                        self?.viewModel?.showCaptcha = false
                        self?.viewModel?.show2FA = false
                        self?.viewModel?.isLoading = false
                        self?.monitoringTimer?.invalidate()
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startMonitoring()
        }
        
        deinit {
            monitoringTimer?.invalidate()
        }
    }
}

struct HiddenDiscordWebView: UIViewRepresentable {
    @ObservedObject var viewModel: LoginViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 900), configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isHidden = false
        
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "logging")
        
        context.coordinator.webView = webView
        context.coordinator.viewModel = viewModel
        context.coordinator.load(url: URL(string: "https://discord.com/login")!)
        
        context.coordinator.viewModel?.webView = webView
        
        // Start background token monitoring immediately
        context.coordinator.startBackgroundTokenMonitoring()
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if viewModel.shouldSubmitLogin {
            context.coordinator.submitLogin()
            Task { @MainActor in 
                viewModel.shouldSubmitLogin = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        static var qrTimer: Timer? = nil
        static var backgroundTokenTimer: Timer? = nil
        weak var webView: WKWebView?
        weak var viewModel: LoginViewModel?
        private var hasSetInitialUserAgent = false
        private var retryCount = 0
        private var qrCodeRetryCount = 0
        private var challengeCheckTimer: Timer?
        
        func load(url: URL) {
            guard let webView = webView else { return }
            
            let isLoginPage = url.absoluteString.starts(with: "https://discord.com/login")
            let userAgent: String? = isLoginPage
                ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
                : "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"
            
            webView.customUserAgent = userAgent
            hasSetInitialUserAgent = true
            
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        func startBackgroundTokenMonitoring() {
            Self.backgroundTokenTimer?.invalidate()
            Self.backgroundTokenTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkForChallengesOrToken()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.extractQRCode(from: webView)
            }
        }
        
        private func retryExtraction(from webView: WKWebView) {
            self.qrCodeRetryCount += 1
            if self.qrCodeRetryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.extractQRCode(from: webView)
                }
            }
        }
        
        func submitLogin() {
            guard let webView = webView,
                  let viewModel = viewModel else { return }
            
            let email = viewModel.email
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let password = viewModel.password
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            
            let js = """
            (function() {
                const emailInput = document.querySelector('input[name="email"], input[autocomplete*="username"]');
                const passwordInput = document.querySelector('input[name="password"], input[type="password"]');
                const loginButton = document.querySelector('button[type="submit"]');
                
                if (!emailInput || !passwordInput || !loginButton) {
                    return 'inputs_not_found';
                }

                function setReactValue(input, value) {
                    const nativeSetter = Object.getOwnPropertyDescriptor(input.__proto__, 'value')?.set;
                    if (nativeSetter) {
                        nativeSetter.call(input, value);
                        const event = new Event('input', { bubbles: true });
                        input.dispatchEvent(event);
                    }
                }

                setReactValue(emailInput, '\(email)');
                setReactValue(passwordInput, '\(password)');
                
                setTimeout(() => loginButton.click(), 200);

                return 'submitted';
            })();
            """
            
            webView.evaluateJavaScript(js) { [weak self] result, error in
                if let error = error {
                    print("JavaScript error: \(error.localizedDescription)")
                }
                
                if let result = result as? String {
                    print("JavaScript result: \(result)")
                }
                
                Task { @MainActor in 
                    if let result = result as? String, result == "submitted" {
                        // Start monitoring for challenges (2FA/captcha)
                        self?.startChallengeMonitoring()
                    } else if let result = result as? String, result == "inputs_not_found" {
                        self?.viewModel?.isLoading = false
                        self?.viewModel?.errorMessage = "Login inputs not found on page"
                    } else {
                        self?.viewModel?.isLoading = false
                        self?.viewModel?.errorMessage = "Failed to submit login"
                    }
                }
            }
        }
        
        func startChallengeMonitoring() {
            challengeCheckTimer?.invalidate()
            retryCount = 0
            
            challengeCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkForChallengesOrToken()
            }
        }
        
        func checkForChallengesOrToken() {
            guard let webView = webView else { return }
            
            let js = """
            (function() {
                // Check for token first
                const iframe = document.createElement("iframe");
                const token = document.body.appendChild(iframe).contentWindow.localStorage.token;
                
                if (token && token !== '""') {
                    return { type: 'token', value: token };
                }

                // Check for 2FA (language-agnostic + multilingual keywords)
                const mfaText = document.body.innerText || '';

                const twoFAKeywords = [
                    // English
                    "Multi", "factor", "authentication", "2FA", "verification code",

                    // Chinese
                    "验证码", // verification code
                    "双重验证", // two-factor authentication
                    "两步验证", // two-step verification

                    // Spanish
                    "autenticación de dos factores",
                    "código de verificación",
                    "verificación en dos pasos",

                    // French
                    "authentification à deux facteurs",
                    "code de vérification",
                    "vérification en deux étapes",

                    // German
                    "Zwei-Faktor-Authentifizierung",
                    "Bestätigungscode",
                    "Zwei-Schritt-Verifizierung",

                    // Japanese
                    "二要素認証", // two-factor authentication
                    "確認コード", // verification code
                    "2段階認証", // two-step verification

                    // Korean
                    "이중 인증", // two-factor authentication
                    "인증 코드", // verification code
                    "2단계 인증", // two-step verification

                    // Russian
                    "двухфакторная аутентификация",
                    "код подтверждения",
                    "двухэтапная проверка",

                    // Arabic
                    "المصادقة الثنائية", // two-factor authentication
                    "رمز التحقق", // verification code
                    "التحقق بخطوتين", // two-step verification

                    // Portuguese
                    "autenticação de dois fatores",
                    "código de verificação",
                    "verificação em duas etapas"
                ];

                const hasKeyword = twoFAKeywords.some(word => mfaText.includes(word));

                const twoFAField = document.querySelector(
                    'input[placeholder*="6"], input[name*="code"], input[type="number"], input[type="tel"]'
                );

                const sixDigitRegex = /\\b\\d{6}\\b/;

                if (hasKeyword || twoFAField || sixDigitRegex.test(mfaText)) {
                    return { type: '2fa' };
                }

                // Check for captcha - more comprehensive detection
                const bodyText = document.body.innerText || '';
                
                const captchaKeywords = [
                    // English
                    "are you human", "verify you", "verify that you", "human verification",
                    "security check", "complete the security check", "prove you're human",
                    "verify yourself", "verification required",
                    
                    // Common captcha text
                    "hcaptcha", "recaptcha", "captcha", "I am human",
                    
                    // Other languages
                    "você é humano", // Portuguese
                    "eres humano", // Spanish  
                    "êtes-vous humain", // French
                    "bist du ein mensch", // German
                    "あなたは人間ですか", // Japanese
                    "你是人类吗", // Chinese
                    "당신은 인간입니까" // Korean
                ];
                
                const hasCaptchaText = captchaKeywords.some(keyword => 
                    bodyText.toLowerCase().includes(keyword.toLowerCase())
                );
                
                const hasCaptchaElement = document.querySelector('iframe[src*="captcha"]') || 
                    document.querySelector('[class*="captcha"]') ||
                    document.querySelector('[class*="Captcha"]') ||
                    document.querySelector('iframe[src*="hcaptcha"]') ||
                    document.querySelector('iframe[src*="recaptcha"]') ||
                    document.querySelector('[id*="captcha"]') ||
                    document.querySelector('div[class*="challenge"]');
                
                if (hasCaptchaText || hasCaptchaElement) {
                    return { type: 'captcha' };
                }

                // Check for error messages
                const errorElement = document.querySelector('[class*="error"], [class*="Error"]');
                if (errorElement && errorElement.innerText) {
                    return { type: 'error', value: errorElement.innerText };
                }

                return { type: 'none' };
            })();
            """
            
            webView.evaluateJavaScript(js) { [weak self] result, error in
                guard let self = self,
                      let dict = result as? [String: Any],
                      let type = dict["type"] as? String else {
                    return
                }
                
                print("Challenge check result: \(type)")
                
                Task { @MainActor in 
                    switch type {
                    case "token":
                        if let token = dict["value"] as? String {
                            let strippedToken = token.replacingOccurrences(of: "\"", with: "")
                            self.viewModel?.token = strippedToken
                            self.viewModel?.isLoading = false
                            self.challengeCheckTimer?.invalidate()
                        }
                        
                    case "2fa":
                        self.viewModel?.show2FA = true
                        self.viewModel?.showCaptcha = false
                        self.challengeCheckTimer?.invalidate()
                        
                    case "captcha":
                        self.viewModel?.showCaptcha = true
                        self.viewModel?.show2FA = false
                        self.challengeCheckTimer?.invalidate()
                        
                    case "error":
                        if let errorMsg = dict["value"] as? String {
                            self.viewModel?.errorMessage = errorMsg
                            self.viewModel?.isLoading = false
                            self.challengeCheckTimer?.invalidate()
                        }
                        
                    case "none":
                        self.retryCount += 1
                        if self.retryCount >= 20 {
                            // After 10 seconds (20 * 0.5s), stop checking
                            self.viewModel?.isLoading = false
                            self.challengeCheckTimer?.invalidate()
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let isLoginPage = url.absoluteString.starts(with: "https://discord.com/login")
                let userAgent = isLoginPage
                    ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
                    : "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"
                
                webView.customUserAgent = userAgent
            }
            
            decisionHandler(.allow)
        }
        
        
        
        deinit {
            challengeCheckTimer?.invalidate()
            Self.backgroundTokenTimer?.invalidate()
        }
    }
}

import Vision

extension UIImage {
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let clampedRect = CGRect(
            x: max(0, min(rect.origin.x, CGFloat(cgImage.width))),
            y: max(0, min(rect.origin.y, CGFloat(cgImage.height))),
            width: max(0, min(rect.width, CGFloat(cgImage.width) - rect.origin.x)),
            height: max(0, min(rect.height, CGFloat(cgImage.height) - rect.origin.y))
        )
        
        guard clampedRect.width > 0, clampedRect.height > 0,
              let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}

extension HiddenDiscordWebView.Coordinator {
    func extractQRCode(from webView: WKWebView) {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            let config = WKSnapshotConfiguration()
            
            Self.qrTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                webView.takeSnapshot(with: config) { [weak self] image, error in
                    if let image = image {
                        print("✅ Screenshot captured successfully")
                        self?.detectAndCropQRCode(from: image)
                    } else if let error = error {
                        print("❌ Screenshot error: \(error.localizedDescription)")
                        self?.retryQRExtraction(from: webView)
                    }
                }
            }
        }
    }
    
    private func detectAndCropQRCode(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            retryQRExtraction(from: webView)
            return
        }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            if let error = error {
                self?.retryQRExtraction(from: self?.webView)
                return
            }
            
            guard let observations = request.results as? [VNBarcodeObservation],
                  let qrCode = observations.first(where: { $0.symbology == .qr }) else {
                self?.retryQRExtraction(from: self?.webView)
                return
            }

            
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)
            let boundingBox = qrCode.boundingBox
            
            let qrRect = CGRect(
                x: boundingBox.origin.x * imageWidth,
                y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            )
            
            let padding: CGFloat = 20
            let paddedRect = CGRect(
                x: max(0, qrRect.origin.x - padding),
                y: max(0, qrRect.origin.y - padding),
                width: min(imageWidth - qrRect.origin.x + padding, qrRect.width + padding * 2),
                height: min(imageHeight - qrRect.origin.y + padding, qrRect.height + padding * 2)
            )
            
            
            if let croppedImage = image.cropped(to: paddedRect) {
                Task { @MainActor in 
                    self?.viewModel?.qrCodeImage = croppedImage
                    self?.qrCodeRetryCount = 0
                }
            } else {
                Task { @MainActor in 
                    self?.viewModel?.qrCodeImage = image
                    self?.qrCodeRetryCount = 0
                }
            }
        }
        
        request.symbologies = [.qr]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            retryQRExtraction(from: webView)
        }
    }
    
    private func retryQRExtraction(from webView: WKWebView?) {
        guard let webView = webView else { return }
        
        qrCodeRetryCount += 1
        if qrCodeRetryCount < 8 {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.extractQRCode(from: webView)
            }
        } else {
            
        }
    }
}

extension HiddenDiscordWebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logging" {
            print("WebView Console: \(message.body)")
        }
    }
}
