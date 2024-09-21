//
//  VideoPlayer.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//


import UIKit
import AVFoundation
import AVKit
import SwiftUI

struct FSVideoPlayer: UIViewControllerRepresentable {
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
