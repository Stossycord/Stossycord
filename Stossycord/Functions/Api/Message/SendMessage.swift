//
//  SendMessage.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

func SendMessage(content: String, fileUrl: URL?, token: String, channel: String, messageReference: [String: String]?) {
    let url = URL(string: "https://discord.com/api/v9/channels/\(channel)/messages")!
    var request = URLRequest(url: url)
    var data = Data()
    request.httpMethod = "POST"
    
    if content.isEmpty && fileUrl == nil {
        return
    }
    
    request.addValue(token, forHTTPHeaderField: "Authorization")
    
    let boundary = "Boundary-\(UUID().uuidString)"
    
    if let fileUrl = fileUrl {
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Append content
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(content)\r\n".data(using: .utf8)!)
        
        // Append file
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileUrl.lastPathComponent)\"\r\n".data(using: .utf8)!)
        
        // Add Content-Type for the file (change accordingly)
        let mimeType = "application/octet-stream" // Default MIME type
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        do {
            let fileData = try Data(contentsOf: fileUrl)
            data.append(fileData)
        } catch {
            print("Failed to read file data")
            return
        }
        
        // Close the boundary
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    }
    
    if fileUrl == nil {
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    let Country: String = CurrentDeviceInfo.shared.Country
    
    let currentTimeZone = CurrentDeviceInfo.shared.currentTimeZone
    
    let timeZoneIdentifier = currentTimeZone.identifier
    
    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    
    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(currentTimeZone)-\(Country)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")
    
    // JSON Body (for non-file message)
    if fileUrl == nil {
        var bodyObject: [String: Any] = ["content": content]
        if let messageReference = messageReference {
            bodyObject["message_reference"] = messageReference
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObject)
    } else {
        request.httpBody = data
    }

    // Create the task
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            print("Response: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }
    task.resume()
}
