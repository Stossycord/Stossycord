//
//  MediaView.swift
//  Stossycord
//
//  Created by Hristos on 18/5/2024.
//

import AVKit
import Foundation
import SwiftUI

struct MediaView: View {
    let url: String

    var body: some View {
        if let url2 = URL(string: url) {
            Group {
                if url2.pathExtension.lowercased() == "mp4" {
                    VideoPlayer(player: AVPlayer(url: url2))
                        .aspectRatio(contentMode: .fit)
                } else if url2.pathExtension.lowercased() == "png" || url2.pathExtension.lowercased() == "jpg" {
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            DownloadView(url: url2)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    DownloadView(url: url2)
                }
            }
        }
    }
}

struct DownloadView: View {
    let url: URL

    var body: some View {
        HStack {
            Text(url.lastPathComponent)
            Button(action: {
                // Open the URL in Safari
                UIApplication.shared.open(url)
            }) {
                Image(systemName: "square.and.arrow.down.fill")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8.0)
    }
}
