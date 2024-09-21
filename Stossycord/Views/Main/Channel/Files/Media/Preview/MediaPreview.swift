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
import Giffy
import AVKit

struct MediaPreview: View {
    @State var file: URL
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
    let audioExtensions = ["mp3", "m4a", "ogg"]
    let imageExtensions = ["jpg", "jpeg", "png", "gif"]
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
