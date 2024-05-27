//
//  ImageSelectorView.swift
//  Stossy11DIscord
//
//  Created by Stossy11 on 20/5/2024.
//
import PhotosUI
import SwiftUI
import AVFoundation

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    var token: String
    var channelid: String
    var message: String

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier("public.movie") {
                provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                    guard let url = url else { return }
                    
                    // If the video is not in mp4 format, convert it
                    if url.pathExtension.lowercased() != "mp4" {
                        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                        convertVideoToMP4(inputURL: url, outputURL: outputURL) { success in
                            if success {
                                self.parent.fileURL = outputURL
                                uploadFileToDiscord2(fileUrl: outputURL, token: self.parent.token, channelid: self.parent.channelid, message: self.parent.message)
                            }
                        }
                    } else {
                        self.parent.fileURL = url
                        uploadFileToDiscord2(fileUrl: url, token: self.parent.token, channelid: self.parent.channelid, message: self.parent.message)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                    guard let url = url else { return }
                    self.parent.fileURL = url
                    uploadFileToDiscord2(fileUrl: url, token: self.parent.token, channelid: self.parent.channelid, message: self.parent.message)
                }
            }
        }
    }
}

func convertVideoToMP4(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
    let asset = AVURLAsset(url: inputURL)
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
        completion(false)
        return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4

    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            completion(true)
        default:
            completion(false)
        }
    }
}


func uploadFileToDiscord2(fileUrl: URL, token: String, channelid: String, message: String) {
    let url = URL(string: "https://discord.com/api/channels/\(channelid)/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(token, forHTTPHeaderField: "Authorization")
    
    let boundary = "Boundary-\(UUID().uuidString)"
    request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var data = Data()
    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
    data.append("\(message)\r\n".data(using: .utf8)!)
    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileUrl.lastPathComponent)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
    
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: fileUrl.path) {
        do {
            let fileData = try Data(contentsOf: fileUrl)
            data.append(fileData)
        } catch {
            print("Failed to read file data")
            return
        }
    } else {
        print("File Doesnt Exist")
        return
    }
    
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    let task = URLSession.shared.uploadTask(with: request, from: data) { (data, response, error) in
        if let error = error {
            print("Failed to upload file: \(error)")
        } else if let data = data {
            print("Response: \(String(data: data, encoding: .utf8) ?? "")")
        }
        
        // Remove the temporary file
        do {
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            print("Failed to remove file: \(error)")
        }
    }
    task.resume()
}
