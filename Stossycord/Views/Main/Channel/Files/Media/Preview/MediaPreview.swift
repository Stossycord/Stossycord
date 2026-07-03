//
//  MediaPreview.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation
import AVFoundation
import OggDecoder
import SwiftUI
import AVKit
#if canImport(Giffy)
import Giffy
#endif

struct MediaPreview: View {
    @State var file: URL
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v", "webm"]
    let audioExtensions = ["mp3", "m4a", "ogg", "wav", "aac", "flac"]
    let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp"]
    var body: some View {
        if videoExtensions.contains(file.pathExtension.lowercased()) {
            FSVideoPlayer(url: file)
        } else if imageExtensions.contains(file.pathExtension.lowercased()) {
            AsyncImage(url: file) { image in
                image
                    .resizable()
            } placeholder: {
                ProgressView()
            }
        } else if file.pathExtension.lowercased() == "gif" || file.pathExtension.lowercased() == "webp"  {
            AnimatedImageView(url: file)
                .aspectRatio(contentMode: .fit)
        } else if audioExtensions.contains(file.pathExtension.lowercased()) {
            if file.pathExtension.lowercased() == "ogg" {
                AudioPlayer(url: file)
            } else {
                AudioPlayer(url: file)
            }
        } else {
            DownloadView(url: file)
        }
    }
}
