//
//  PhotoPickerView.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotoPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var savedImagePath: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var onImageSaved: ((URL) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            PhotosPicker(selection: $selectedItem,
                         matching: .any(of: [.images, .videos])) {
                Text("Select Photo")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .onChange(of: selectedItem) { _ in
            Task {
                await loadTransferredMedia()
                if let savedImagePath {
                    onImageSaved?(savedImagePath)
                }
            }
        }
    }
    
    private func loadTransferredMedia() async {
        do {
            guard let selectedItem else { return }
            
            // Check if the selected item is a video or image using UTType
            if let mediaData = try await selectedItem.loadTransferable(type: Data.self) {
                let isVideos = selectedItem.supportedContentTypes
                
                print(isVideos.first!.identifier)
                
                let isVideo = isVideos.first!.identifier.contains("mpeg")
                // Get temporary directory URL
                let temporaryDirectory = FileManager.default.temporaryDirectory
                let fileExtension = isVideo ? "mp4" : "jpg"
                let fileName = UUID().uuidString + "." + fileExtension
                let fileURL = temporaryDirectory.appendingPathComponent(fileName)
                
                // Write the media data to temporary directory
                try mediaData.write(to: fileURL)
                
                // Update the saved media path
                await MainActor.run {
                    savedImagePath = fileURL
                    alertMessage = ""
                    showAlert = true
                }
            } else {
                throw NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to load media data"])
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "Failed to save media: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}
