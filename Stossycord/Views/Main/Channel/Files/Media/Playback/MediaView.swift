//
//  MediaView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation
import AVFoundation
import ImageIO
import OggDecoder
import SwiftUI
import AVKit

private enum MediaKind: Equatable, Sendable {
    case animatedImage
    case staticImage
    case video
    case audio
    case download
}

struct MediaView: View {
    let url: String
    let proxyURL: String?
    let contentType: String?
    let filename: String?
    let isCurrentUser: Bool?
    let maxDimension: CGFloat
    
    @State private var kind: MediaKind? = nil
    @State private var loadedData: Data? = nil
    @State private var thumbnailImage: UIImage? = nil
    @State private var resolvedURL: URL? = nil
    @State private var loadFailed = false
    @State private var isLoading = false
    
    init(
        url: String,
        proxyURL: String? = nil,
        contentType: String? = nil,
        filename: String? = nil,
        isCurrentUser: Bool? = nil,
        maxDimension: CGFloat = 300
    ) {
        self.url = url
        self.proxyURL = proxyURL
        self.contentType = contentType
        self.filename = filename
        self.isCurrentUser = isCurrentUser
        self.maxDimension = maxDimension
    }
    
    init(attachment: Attachment, isCurrentUser: Bool? = nil, maxDimension: CGFloat = 300) {
        self.init(
            url: attachment.url,
            proxyURL: attachment.proxyUrl,
            contentType: attachment.contentType,
            filename: attachment.filename,
            isCurrentUser: isCurrentUser,
            maxDimension: maxDimension
        )
    }
    
    var body: some View {
        Group {
            if loadFailed {
                if let u = URL(string: url) {
                    DownloadView(url: u)
                } else {
                    Text("Invalid URL").foregroundColor(.secondary)
                }
            } else if let kind, let resolvedURL {
                mediaBody(kind: kind, url: resolvedURL)
            } else {
                placeholder
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: isCurrentUser == nil ? .center
            : isCurrentUser == true ? .trailing : .leading
        )
        .task(id: loadKey) { await loadMedia() }
    }
    
    private var loadKey: String {
        [url, proxyURL, contentType, filename].compactMap { $0 }.joined(separator: "|")
    }
    
    @ViewBuilder
    private func mediaBody(kind: MediaKind, url: URL) -> some View {
        switch kind {
        case .animatedImage:
            if let data = loadedData {
                WebAnimatedImageView(data: data)
                    .frame(maxWidth: maxDimension, maxHeight: maxDimension)
                    .contextMenu { saveButton }
            }
        case .staticImage:
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxDimension, maxHeight: maxDimension)
                    .contextMenu { saveButton }
            } else {
                placeholder
            }
        case .video:
            FSVideoPlayer(url: url)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: maxDimension, maxHeight: maxDimension)
                .clipped()
                .contextMenu { saveButton }
        case .audio:
            AudioPlayer(url: url)
                .contextMenu { saveButton }
        case .download:
            DownloadView(url: url)
        }
    }
    
    @ViewBuilder
    private var saveButton: some View {
        Button { } label: { Text("Save to Photos") }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.12))
            .frame(maxWidth: maxDimension, maxHeight: maxDimension)
    }
    
    @MainActor
    private func resetForLoad() {
        isLoading = true
        loadFailed = false
        kind = nil
        loadedData = nil
        thumbnailImage = nil
        resolvedURL = nil
    }
    
    private func loadMedia() async {
        await resetForLoad()
        
        guard let originalURL = URL(string: url) else {
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
            return
        }
        
        let metadataKind = metadataKind(for: originalURL)
        let mediaURL: URL
        if metadataKind == .animatedImage {
            mediaURL = originalURL
        } else {
            mediaURL = URL(string: proxyURL ?? "") ?? originalURL
        }
        let maxPixelDimension = max(1, Int(maxDimension * UIScreen.main.scale))
        
        if let metadataKind, metadataKind != .staticImage, metadataKind != .animatedImage {
            await MainActor.run {
                resolvedURL = originalURL
                kind = metadataKind
                isLoading = false
            }
            return
        }
        
        do {
            let result = try await Task.detached(priority: .utility) {
                try await loadMediaPayload(
                    originalURL: originalURL,
                    mediaURL: mediaURL,
                    metadataKind: metadataKind,
                    maxPixelDimension: maxPixelDimension
                )
            }.value
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                resolvedURL = result.resolvedURL
                kind = result.kind
                loadedData = result.animatedData
                thumbnailImage = result.thumbnail
                loadFailed = false
                isLoading = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
        }
    }
    
    private func metadataKind(for url: URL) -> MediaKind? {
        if let contentType = contentType?.lowercased(),
           let kind = classifyMIME(contentType) {
            return kind
        }
        
        let filenameExtension = filename.flatMap { URL(fileURLWithPath: $0).pathExtension }
        let ext = ((filenameExtension?.isEmpty == false ? filenameExtension : nil) ?? url.pathExtension).lowercased()
        
        switch ext {
        case "gif", "webp":
            return .animatedImage
        case "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp":
            return .staticImage
        case "mp4", "mov", "m4v", "webm":
            return .video
        case "mp3", "m4a", "wav", "aac", "flac", "ogg":
            return .audio
        default:
            return nil
        }
    }
}

private struct MediaLoadResult: @unchecked Sendable {
    let kind: MediaKind
    let resolvedURL: URL
    let animatedData: Data?
    let thumbnail: UIImage?
}

private func loadMediaPayload(
    originalURL: URL,
    mediaURL: URL,
    metadataKind: MediaKind?,
    maxPixelDimension: Int
) async throws -> MediaLoadResult {
    let (data, response) = try await URLSession.shared.data(from: mediaURL)
    let mime = (response as? HTTPURLResponse)?.mimeType ?? ""
    let detectedKind = metadataKind ?? bodySniff(data: data, mimeType: mime)
    
    switch detectedKind {
    case .animatedImage:
        return MediaLoadResult(kind: detectedKind, resolvedURL: mediaURL, animatedData: data, thumbnail: nil)
    case .staticImage:
        let thumbnail = downsampleImage(data: data, maxPixelDimension: maxPixelDimension)
        return MediaLoadResult(kind: detectedKind, resolvedURL: mediaURL, animatedData: nil, thumbnail: thumbnail)
    case .video, .audio, .download:
        return MediaLoadResult(kind: detectedKind, resolvedURL: originalURL, animatedData: nil, thumbnail: nil)
    }
}

private func bodySniff(data: Data, mimeType: String) -> MediaKind {
    if data.isGIF || data.isAnimatedWebP { return .animatedImage }
    if data.isWebP || data.isPNG || data.isJPEG { return .staticImage }
    if data.isMPEG4 || data.isQuickTime { return .video }
    if data.isMP3 || data.isM4A { return .audio }
    return classifyMIME(mimeType) ?? .download
}

private func classifyMIME(_ mime: String) -> MediaKind? {
    if mime.contains("gif") { return .animatedImage }
    if mime.contains("webp") { return .animatedImage }
    if mime.contains("image/") { return .staticImage }
    if mime.contains("video/") { return .video }
    if mime.contains("audio/") || mime.contains("ogg") { return .audio }
    return nil
}

private func downsampleImage(data: Data, maxPixelDimension: Int) -> UIImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
    
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
    ] as CFDictionary
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    return UIImage(cgImage: cgImage)
}

private extension Data {
    var isGIF: Bool {
        count >= 6 && self[0] == 0x47 && self[1] == 0x49 && self[2] == 0x46
    }
    
    var isWebP: Bool {
        count >= 12 &&
        self[0] == 0x52 && self[1] == 0x49 && self[2] == 0x46 && self[3] == 0x46 &&
        self[8] == 0x57 && self[9] == 0x45 && self[10] == 0x42 && self[11] == 0x50
    }
    
    var isAnimatedWebP: Bool {
        guard isWebP, count > 20 else { return false }
        let limit = Swift.min(count - 3, 64)
        for i in 12..<limit {
            if self[i] == 0x41 && self[i+1] == 0x4E && self[i+2] == 0x49 && self[i+3] == 0x4D {
                return true
            }
        }
        return false
    }
    
    var isPNG: Bool {
        count >= 4 && self[0] == 0x89 && self[1] == 0x50 && self[2] == 0x4E && self[3] == 0x47
    }
    
    var isJPEG: Bool {
        count >= 3 && self[0] == 0xFF && self[1] == 0xD8 && self[2] == 0xFF
    }
    
    var isMPEG4: Bool {
        count >= 8 &&
        self[4] == 0x66 && self[5] == 0x74 && self[6] == 0x79 && self[7] == 0x70
    }
    
    var isQuickTime: Bool {
        guard count >= 12 else { return false }
        return isMPEG4 && self[8] == 0x71 && self[9] == 0x74
    }
    
    var isMP3: Bool {
        count >= 3 && self[0] == 0x49 && self[1] == 0x44 && self[2] == 0x33
    }
    
    var isM4A: Bool {
        count >= 12 && isMPEG4 && self[8] == 0x4D && self[9] == 0x34 && self[10] == 0x41
    }
}
