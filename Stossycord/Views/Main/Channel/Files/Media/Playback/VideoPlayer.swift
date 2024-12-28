//
//  VideoPlayer.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//


import SwiftUI
import AVFoundation
import AVKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct FSVideoPlayer: View {
    var url: URL

    #if os(macOS)
    var body: some View {
        VideoPlayerMac(url: url)
    }
    #else
    var body: some View {
        VideoPlayeriOS(url: url)
    }
    #endif
}

#if os(macOS)
struct VideoPlayerMac: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player = AVPlayer(url: url)
        playerView.player = player
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Update the view if needed, e.g., changing the player or its properties.
        nsView.player?.replaceCurrentItem(with: AVPlayerItem(url: url))
    }
}
#else
struct VideoPlayeriOS: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update the controller if needed.
    }
}
#endif
