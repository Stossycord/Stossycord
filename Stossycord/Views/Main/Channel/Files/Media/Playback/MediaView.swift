//
//  MediaView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation
import AVFoundation
import OggDecoder
import SwiftUI
#if os(iOS)
import Giffy
#endif
import AVKit

struct MediaView: View {
    @State var savefile = false
    let url: String
    var urlToExport: URL? { URL(string: url) }
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
    let audioExtensions = ["mp3", "m4a", "ogg"]
    let imageExtensions = ["jpg", "jpeg", "png"]

    // Target maximum width or height for resized content
    let maxDimension: CGFloat = 300.0

    // Function to calculate the scaled dimensions while keeping the aspect ratio
    func scaledSize(for size: CGSize) -> CGSize {
        let aspectRatio = size.width / size.height
        if size.width > size.height {
            return CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            return CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
    }

    var body: some View {
        if let url2 = URL(string: url) {
            Group {
                if videoExtensions.contains(url2.pathExtension.lowercased()) {
                    FSVideoPlayer(url: url2)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: maxDimension, height: maxDimension)
                        .contextMenu {
                            Button { savefile = true } label: { Text("Save to photos") }
                        }
                } else if imageExtensions.contains(url2.pathExtension.lowercased()) {
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: maxDimension, height: maxDimension)
                                .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                        case .failure: DownloadView(url: url2)
                        @unknown default: EmptyView()
                        }
                    }
                } else if url2.pathExtension.lowercased() == "gif" {
#if !os(macOS)
                    AsyncGiffy(url: url2) { phase in
                        switch phase {
                        case .loading: ProgressView()
                        case .error: DownloadView(url: url2)
                        case .success(let giffy):
                            giffy.frame(width: 32, height: 32).clipShape(Circle())
                                .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                        }
                    }
#else
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: maxDimension, height: maxDimension)
                                .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                        case .failure: DownloadView(url: url2)
                        @unknown default: EmptyView()
                        }
                    }
#endif
                    
                } else if audioExtensions.contains(url2.pathExtension.lowercased()) {
                    AudioPlayer(url: url2)
                        .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                } else {
                    DownloadView(url: url2)
                }
            }
        }
    }
}
