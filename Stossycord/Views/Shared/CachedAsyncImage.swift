import SwiftUI
import Foundation
import ImageIO

#if os(iOS)
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _ in
            image = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString) {
            if let cachedImage = downsampleCachedUIImage(data: cachedData) {
                self.image = cachedImage
                return
            }
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            let decodedImage = data.flatMap(downsampleCachedUIImage)
            Task { @MainActor in 
                isLoading = false
                
                if let data = data, let decodedImage {
                    CacheService.shared.setCachedProfilePicture(data, url: urlString)
                    self.image = decodedImage
                }
            }
        }.resume()
    }
}

private func downsampleCachedUIImage(data: Data) -> UIImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
    
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 900
    ] as CFDictionary
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    return UIImage(cgImage: cgImage)
}

#elseif os(macOS)
import AppKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(nsImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _ in
            image = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString) {
            if let cachedImage = NSImage(data: cachedData) {
                self.image = cachedImage
                return
            }
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            let decodedImage = data.flatMap(NSImage.init(data:))
            Task { @MainActor in 
                isLoading = false
                
                if let data = data, let decodedImage {
                    CacheService.shared.setCachedProfilePicture(data, url: urlString)
                    self.image = decodedImage
                }
            }
        }.resume()
    }
}
#endif
