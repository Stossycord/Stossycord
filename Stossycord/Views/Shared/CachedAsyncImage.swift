import SwiftUI
import Foundation

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
            if let cachedImage = UIImage(data: cachedData) {
                self.image = cachedImage
                return
            }
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let downloadedImage = UIImage(data: data) {
                    CacheService.shared.setCachedProfilePicture(data, url: urlString)
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
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
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let downloadedImage = NSImage(data: data) {
                    CacheService.shared.setCachedProfilePicture(data, url: urlString)
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
}
#endif