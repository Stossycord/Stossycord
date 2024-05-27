//
//  MediaView.swift
//  Stossycord
//
//  Created by Stossy11 on 18/5/2024.
//

import Giffy
import AVKit
import AVFAudio
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import OggDecoder

struct MediaView: View {
    @State var savefile = false
    let url: String
    var urlToExport: URL? { URL(string: url) }
    
    var body: some View {
        if let url2 = URL(string: url) {
            Group {
                if url2.pathExtension.lowercased() == "mp4" {
                    VideoPlayer(player: AVPlayer(url: url2))
                        .aspectRatio(contentMode: .fit)
                        .contextMenu {
                            // Show the message date when holding the message
                            Text("To Reply hold the user icon")
                            Button(action: {
                            }) {
                                Text("Save to files")
                            }
                            Button(action: {
                                // self.replyMessage = Message(id: messageData.messageId, content: messageData.message, username: messageData.username)
                                savefile = true
                                print("Save: \(savefile)")
                            }) {
                                Text("Save to photos")
                            }
                        }
                } else if url2.pathExtension.lowercased() == "png" || url2.pathExtension.lowercased() == "jpg" {
                    AsyncImage(url: url2) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                                .contextMenu {
                                    // Show the message date when holding the message
                                    Text("To Reply hold the user icon")
                                    Button(action: {
                                        
                                    }) {
                                        Text("Save to files")
                                    }
                                    
                                    Button(action: {
                                        // self.replyMessage = Message(id: messageData.messageId, content: messageData.message, username: messageData.username)
                                        savefile = true
                                        print("Save: \(savefile)")
                                    }) {
                                        Text("Save to Photos")
                                    }
                                }
                        case .failure:
                            DownloadView(url: url2)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if url2.pathExtension.lowercased() == "gif"  {
                    AsyncGiffy(url: URL(string: url)!) { phase in
                        switch phase {
                        case .loading:
                            ProgressView()
                        case .error:
                            DownloadView(url: url2)
                        case .success(let giffy):
                            giffy
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .onAppear() {
                                    print("giffff")
                                }
                                .contextMenu {
                                    // Show the message date when holding the message
                                    Text("To Reply hold the user icon")
                                    Button(action: {
                                    }) {
                                        Text("Save to files")
                                    }
                                    Button(action: {
                                        // self.replyMessage = Message(id: messageData.messageId, content: messageData.message, username: messageData.username)
                                        savefile = true
                                        print("Save: \(savefile)")
                                    }) {
                                        Text("Save to Photos")
                                    }
                                }
                        }
                    }
                } else if url2.pathExtension.lowercased() == "mp3" {
                    MP3PlayerView(url: URL(string: url)!, isOGG: false)
                        .contextMenu {
                            // Show the message date when holding the message
                            Text("To Reply hold the user icon")
                            Button(action: {
                            }) {
                                Text("Save to files")
                            }
                        }
                } else if url2.pathExtension.lowercased() == "ogg" {
                    MP3PlayerView(url: URL(string: url)!, isOGG: true)
                        .contextMenu {
                            // Show the message date when holding the message
                            Text("To Reply hold the user icon")
                            Button(action: {
                            }) {
                                Text("Save to files")
                            }
                        }
                } else {
                    DownloadView(url: url2)
                }
            }
        }
    }
}


func downloadOGGFile(from urlString: String, completion: @escaping (URL?) -> Void) {
    guard let url = URL(string: urlString) else {
        print("Invalid URL string.")
        completion(nil)
        return
    }
    
    let uuid = UUID().uuidString
    
    let fileManager = FileManager.default
    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let destinationURL = documentsDirectory.appendingPathComponent("\(uuid).ogg")
    
    // Download the new file
    let task = URLSession.shared.downloadTask(with: url) { tempLocalUrl, response, error in
        if let error = error {
            print("Failed to download file: \(error)")
            completion(nil)
            return
        }
        
        guard let tempLocalUrl = tempLocalUrl else {
            print("No file URL.")
            completion(nil)
            return
        }
        
        do {
            try fileManager.moveItem(at: tempLocalUrl, to: destinationURL)
            print("File downloaded and saved to \(destinationURL)")
            completion(destinationURL)
        } catch {
            print("Failed to move file: \(error)")
            completion(nil)
        }
    }
    
    task.resume()
}


struct MP3PlayerView: View {
    let url: URL
    let isOGG: Bool
    @State var fileurl = URL(string: "")
    @State private var player: AVPlayer?
    @State private var oggplayer: AVAudioPlayer?
    @State private var progress: Double = 0
    @State var beans = false
    @State var beansv2 = "play.fill"
    let fileManager = FileManager.default

    var body: some View {
        VStack {
            HStack {
                Text(url.lastPathComponent)
                Button(action: {
                    // Play the MP3
                    if url.pathExtension == "ogg" {
                        if !beans {
                            var desturl = "\(url)"
                            let decoder = OGGDecoder()
                            downloadOGGFile(from: desturl) { beansman in
                                if let shrek = beansman {
                                    decoder.decode(shrek) { (savedWavUrl: URL?) in
                                        if savedWavUrl == nil {
                                            print("uhoh")
                                        } else {
                                            if let actualsavedwav = savedWavUrl {
                                                progress = 0
                                                fileurl = savedWavUrl
                                                do {
                                                    self.oggplayer = try AVAudioPlayer(contentsOf: fileurl!)
                                                    self.oggplayer?.play()
                                                    startProgressMonitoringOGG()
                                                    beansv2 = "stop.fill"
                                                    beans = true
                                                } catch let error {
                                                    print("Error loading file: \(error.localizedDescription)")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            if fileManager.fileExists(atPath: fileurl!.path) {
                                do {
                                    try FileManager.default.removeItem(at: fileurl!)
                                    self.oggplayer?.stop()
                                    beansv2 = "play.fill"
                                    beans = false
                                } catch {
                                    print("Failed to delete ogg file: \(error)")
                                }
                            }
                        }
                    } else {
                        if !beans {
                            progress = 0
                            self.player = AVPlayer(url: url)
                            self.player?.play()
                            startProgressMonitoring()
                            beansv2 = "stop.fill"
                            beans = true
                        } else {
                            self.player?.pause()
                            beansv2 = "play.fill"
                            beans = false
                        }
                    }
                }) {
                    Image(systemName: beansv2)
                }
            }

            if url.pathExtension == "ogg" {
                Slider(value: $progress, in: 0...1, onEditingChanged: { _ in
                    if let duration = self.oggplayer?.duration {
                        let newTime = duration * progress
                        self.oggplayer?.currentTime = newTime
                    }
                })
            } else {
                Slider(value: $progress, in: 0...1, onEditingChanged: { _ in
                    if let duration = self.player?.currentItem?.duration {
                        let newTime = CMTimeMakeWithSeconds(duration.seconds * progress, preferredTimescale: 600)
                        self.player?.seek(to: newTime)
                    }
                })
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8.0)
    }

    func startProgressMonitoring() {
        guard let player = player else { return }
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { time in
            if let duration = player.currentItem?.duration {
                self.progress = time.seconds / duration.seconds
            }
        }
    }
    
    func startProgressMonitoringOGG() {
        guard let player = oggplayer else { return }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if player.isPlaying {
                self.progress = player.currentTime / player.duration
            } else {
                timer.invalidate()
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
