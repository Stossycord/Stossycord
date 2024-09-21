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
import Giffy
import AVKit

struct MediaView: View {
    @State var savefile = false
    let url: String
    var urlToExport: URL? { URL(string: url) }
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
    let audioExtensions = ["mp3", "m4a", "ogg"]
    let imageExtensions = ["jpg", "jpeg", "png"]

    var body: some View {
        if let url2 = URL(string: url) {
            Group {
                if videoExtensions.contains(url2.pathExtension.lowercased()) {
                    FSVideoPlayer(url: url2)
                        .aspectRatio(contentMode: .fit)
                        .contextMenu {
                            Button { savefile = true } label: { Text("Save to photos") }
                        }
                } else if imageExtensions.contains(url2.pathExtension.lowercased()) {
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                                .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                        case .failure: DownloadView(url: url2)
                        @unknown default: EmptyView()
                        }
                    }
                } else if url2.pathExtension.lowercased() == "gif" {
                    AsyncGiffy(url: url2) { phase in
                        switch phase {
                        case .loading: ProgressView()
                        case .error: DownloadView(url: url2)
                        case .success(let giffy):
                            giffy.frame(width: 32, height: 32).clipShape(Circle())
                                .contextMenu { Button { savefile = true } label: { Text("Save to photos") } }
                        }
                    }
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
