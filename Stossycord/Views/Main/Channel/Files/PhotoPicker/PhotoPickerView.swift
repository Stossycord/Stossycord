//
//  PhotoPickerView.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotoPickerView: UIViewControllerRepresentable {
    var onImageSaved: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.preferredAssetRepresentationMode = .current
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSaved: onImageSaved, onCancel: onCancel)
    }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImageSaved: ((URL) -> Void)?
        private let onCancel: (() -> Void)?
        
        init(onImageSaved: ((URL) -> Void)?, onCancel: (() -> Void)?) {
            self.onImageSaved = onImageSaved
            self.onCancel = onCancel
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                picker.dismiss(animated: true)
                onCancel?()
                return
            }
            
            savePickedMedia(from: result.itemProvider) { [weak picker] url in
                DispatchQueue.main.async {
                    picker?.dismiss(animated: true)
                    if let url {
                        self.onImageSaved?(url)
                    }
                }
            }
        }
        
        private func savePickedMedia(from itemProvider: NSItemProvider, completion: @escaping (URL?) -> Void) {
            guard let typeIdentifier = preferredTypeIdentifier(for: itemProvider) else {
                completion(nil)
                return
            }
            
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
                if let url, error == nil, let savedURL = self?.copyTemporaryMedia(from: url, typeIdentifier: typeIdentifier) {
                    completion(savedURL)
                    return
                }
                
                itemProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
                    guard let data, let savedURL = self?.writeTemporaryMedia(data, typeIdentifier: typeIdentifier) else {
                        completion(nil)
                        return
                    }
                    
                    completion(savedURL)
                }
            }
        }
        
        private func preferredTypeIdentifier(for itemProvider: NSItemProvider) -> String? {
            let types = itemProvider.registeredTypeIdentifiers.compactMap(UTType.init)
            
            if let movieType = types.first(where: { $0.conforms(to: .movie) }) {
                return movieType.identifier
            }
            
            if let imageType = types.first(where: { $0.conforms(to: .image) }) {
                return imageType.identifier
            }
            
            return itemProvider.registeredTypeIdentifiers.first
        }
        
        private func copyTemporaryMedia(from sourceURL: URL, typeIdentifier: String) -> URL? {
            do {
                let destinationURL = try makeTemporaryMediaURL(typeIdentifier: typeIdentifier, sourceURL: sourceURL)
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL
            } catch {
                print("Failed to copy picked media: \(error.localizedDescription)")
                return nil
            }
        }
        
        private func writeTemporaryMedia(_ data: Data, typeIdentifier: String) -> URL? {
            do {
                let destinationURL = try makeTemporaryMediaURL(typeIdentifier: typeIdentifier)
                try data.write(to: destinationURL)
                return destinationURL
            } catch {
                print("Failed to save picked media: \(error.localizedDescription)")
                return nil
            }
        }
        
        private func makeTemporaryMediaURL(typeIdentifier: String, sourceURL: URL? = nil) throws -> URL {
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            
            let contentType = UTType(typeIdentifier)
            let fileExtension = sourceURL?.pathExtension.isEmpty == false ? sourceURL?.pathExtension : contentType?.preferredFilenameExtension
            
            return temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension ?? "dat")
        }
    }
}
