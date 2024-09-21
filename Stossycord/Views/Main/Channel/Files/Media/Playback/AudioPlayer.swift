//
//  AudioPlayer.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import OggDecoder
import AVFoundation

struct AudioPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var oggPlayer: AVAudioPlayer?
    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var playButtonIcon = "play.fill"
    @State private var oggFileURL: URL?
    let fileManager = FileManager.default
    
    var body: some View {
        VStack {
            HStack {
                Text(url.lastPathComponent)
                Button(action: togglePlayPause) {
                    Image(systemName: playButtonIcon)
                }
            }
            Slider(value: $progress, in: 0...1, onEditingChanged: sliderChanged)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8.0)
    }
    
    func togglePlayPause() {
        if url.pathExtension == "ogg" {
            toggleOGGPlayback()
        } else {
            toggleMP3Playback()
        }
    }
    
    func toggleOGGPlayback() {
        if isPlaying {
            stopOGGPlayback()
        } else {
            if oggPlayer == nil {
                decodeAndPlayOGG()
            } else {
                oggPlayer?.play()
                startProgressMonitoringOGG()
                playButtonIcon = "stop.fill"
                isPlaying = true
            }
        }
    }

    func decodeAndPlayOGG() {
        let decoder = OGGDecoder()
        downloadOGGFile(from: url.absoluteString) { oggData in
            guard let oggData = oggData else { return }
            decoder.decode(oggData) { decodedURL in
                if let decodedURL = decodedURL {
                    do {
                        oggFileURL = decodedURL
                        oggPlayer = try AVAudioPlayer(contentsOf: decodedURL)
                        oggPlayer?.play()
                        startProgressMonitoringOGG()
                        playButtonIcon = "stop.fill"
                        isPlaying = true
                    } catch {
                        print("Error loading OGG file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func stopOGGPlayback() {
        oggPlayer?.stop()
        playButtonIcon = "play.fill"
        isPlaying = false
        if let oggFileURL = oggFileURL, fileManager.fileExists(atPath: oggFileURL.path) {
            try? fileManager.removeItem(at: oggFileURL)
        }
    }

    func toggleMP3Playback() {
        if isPlaying {
            player?.pause()
        } else {
            player = AVPlayer(url: url)
            player?.play()
            startProgressMonitoring()
        }
        isPlaying.toggle()
        playButtonIcon = isPlaying ? "stop.fill" : "play.fill"
    }
    
    func sliderChanged(_ editing: Bool) {
        if editing {
            if url.pathExtension == "ogg", let duration = oggPlayer?.duration {
                oggPlayer?.currentTime = duration * progress
            } else if let duration = player?.currentItem?.duration {
                let newTime = CMTime(seconds: duration.seconds * progress, preferredTimescale: 600)
                player?.seek(to: newTime)
            }
        }
    }
    
    func startProgressMonitoring() {
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { time in
            if let duration = player?.currentItem?.duration {
                self.progress = time.seconds / duration.seconds
            }
        }
    }
    
    func startProgressMonitoringOGG() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let oggPlayer = oggPlayer, oggPlayer.isPlaying {
                self.progress = oggPlayer.currentTime / oggPlayer.duration
            } else {
                timer.invalidate()
            }
        }
    }
}
