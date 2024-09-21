//
//  OGGDecoder.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

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

