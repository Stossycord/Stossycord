//
//  AnimatedImageView.swift
//  Stossycord
//
//  Created by Stossy11 on 23/5/2026.
//


import SwiftUI
import WebKit
import ImageIO

struct AnimatedImageView: View {
    let url: URL
    
    var forceWebRenderer: Bool = false

    @State private var detectedFormat: ImageFormat = .unknown
    @State private var imageData: Data? = nil
    @State private var staticImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var loadError: Error? = nil

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(error)
            } else if let data = imageData {
                switch detectedFormat {
                case .gif, .animatedWebP:
                    WebAnimatedImageView(data: data)
                case .staticImage, .unknown:
                    if forceWebRenderer, let data = imageData {
                        WebAnimatedImageView(data: data)
                    } else {
                        staticImageView
                    }
                }
            } else if let staticImage {
                Image(uiImage: staticImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private var loadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .overlay(ProgressView())
    }

    private func errorView(_ error: Error) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }

    private var staticImageView: some View {
        Group {
            if let uiImage = staticImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
            }
        }
    }
    
    private func loadImage() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
            imageData = nil
            staticImage = nil
            detectedFormat = .unknown
        }

        do {
            let result = try await Task.detached(priority: .utility) {
                try await loadAnimatedImagePayload(url: url)
            }.value
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                detectedFormat = result.format
                imageData = result.data
                staticImage = result.staticImage
                isLoading = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                loadError = error
                isLoading = false
            }
        }
    }
}

private struct AnimatedImageLoadResult: @unchecked Sendable {
    let format: ImageFormat
    let data: Data?
    let staticImage: UIImage?
}

private func loadAnimatedImagePayload(url: URL) async throws -> AnimatedImageLoadResult {
    let (data, response) = try await URLSession.shared.data(from: url)
    let mimeType = (response as? HTTPURLResponse)?.mimeType ?? ""
    let format = ImageFormat.detect(data: data, mimeType: mimeType)
    
    switch format {
    case .gif, .animatedWebP:
        return AnimatedImageLoadResult(format: format, data: data, staticImage: nil)
    case .staticImage, .unknown:
        return AnimatedImageLoadResult(format: format, data: nil, staticImage: downsampleAnimatedStaticImage(data: data))
    }
}

private func downsampleAnimatedStaticImage(data: Data) -> UIImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
        return UIImage(data: data)
    }
    
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 900
    ] as CFDictionary
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
        return UIImage(data: data)
    }
    
    return UIImage(cgImage: cgImage)
}

enum ImageFormat {
    case gif
    case animatedWebP
    case staticImage
    case unknown

    static func detect(data: Data, mimeType: String) -> ImageFormat {
        if data.isGIF { return .gif }
        if data.isAnimatedWebP { return .animatedWebP }
        if data.isWebP || mimeType.contains("webp") ||
            mimeType.contains("png") || mimeType.contains("jpeg") {
            return .staticImage
        }
        return .staticImage
    }
}

private extension Data {
    var isGIF: Bool {
        count >= 6 && self[0] == 0x47 && self[1] == 0x49 && self[2] == 0x46
    }

    /// WebP: RIFF????WEBP
    var isWebP: Bool {
        count >= 12 &&
        self[0] == 0x52 && self[1] == 0x49 && self[2] == 0x46 && self[3] == 0x46 &&
        self[8] == 0x57 && self[9] == 0x45 && self[10] == 0x42 && self[11] == 0x50
    }

    var isAnimatedWebP: Bool {
        guard isWebP, count > 20 else { return false }
        let searchRange = Swift.min(count, 64)
        for i in 12..<(searchRange - 3) {
            if self[i]     == 0x41 && // A
               self[i + 1] == 0x4E && // N
               self[i + 2] == 0x49 && // I
               self[i + 3] == 0x4D {  // M
                return true
            }
        }
        return false
    }
}

struct WebAnimatedImageView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        load(data: data, into: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        load(data: data, into: webView)
    }
    
    private func load(data: Data, into webView: WKWebView) {
        let base64 = data.base64EncodedString()
        
        let mime: String
        if data.isGIF {
            mime = "image/gif"
        } else if data.isWebP {
            mime = "image/webp"
        } else {
            mime = "image/png"
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background: transparent; }
          img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            display: block;
          }
        </style>
        </head>
        <body>
          <img src="data:\(mime);base64,\(base64)" />
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
}

extension AnimatedImageView {
    init?(urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        self.init(url: url)
    }
}
