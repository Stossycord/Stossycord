//
//  MediaView.swift
//  Stossycord
//
//  Created by Hristos Sfikas on 18/5/2024.
//

import SwiftUI
import AVKit

struct MediaView: View {
    let url: String

    var body: some View {
        if let url2 = URL(string: url) {
            Group {
                if url2.pathExtension.lowercased() == "mp4" {
                    VideoPlayer(player: AVPlayer(url: url2))
                        .aspectRatio(contentMode: .fit)
                } else {
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            Text("Failed to load image")
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}
