//
//  ImageSelectorView.swift
//  Stossy11DIscord
//
//  Created by Hristos Sfikas on 20/5/2024.
//
import PhotosUI
import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var token: String
    var channelid: String
    var message: String

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
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
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    self.parent.image = image as? UIImage
                    
                    // Save the image to a temporary directory
                    let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
                    if let image = self.parent.image, let data = image.pngData() {
                        try? data.write(to: fileUrl)
                        
                        // Call the upload function
                        uploadFileToDiscord2(fileUrl: fileUrl, token: self.parent.token, channelid: self.parent.channelid, message: self.parent.message)
                    }
                }
            }
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
    do {
        let fileData = try Data(contentsOf: fileUrl)
        data.append(fileData)
    } catch {
        print("Failed to read file data")
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
