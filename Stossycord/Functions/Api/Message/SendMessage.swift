//
//  SendMessage.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation
import UniformTypeIdentifiers

class SendMessage: DiscordRequest<Message>, APIRequest {
    typealias Response = Message
    
    var endpoint: String = ""
    var method: String = "POST"
     
    var args: (channel: String, content: String, fileURL: URL?, messageReference: [String: String]?)
    
    init(channel: String, content: String, fileURL: URL? = nil, messageReference: [String: String]? = nil) {
        args = (channel, content, fileURL, messageReference)
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        
        let channel = self.args.channel
        let content = self.args.content
        
        let fileURL = self.args.fileURL
        
        
 
        var request = makeUrlRequest(url: makeAPIUrl("channels/\(channel)/messages"), json: fileURL == nil)
        
        let messageReference = self.args.messageReference
        
        if content.isEmpty && fileURL == nil {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var data = Data()
        
        let nonce = generateDiscordNonce()
        if fileURL == nil {
            var bodyObject: [String: Any] = ["mobile_network_type":"unknown", "content": content, "nonce": nonce, "tts": false]
            if let messageReference = messageReference {
                bodyObject["message_reference"] = messageReference
                
            }
            bodyObject["flags"] = 0
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObject)
        } else {
            guard let fileUrl = fileURL else { return request }
            let filename = fileUrl.lastPathComponent
            var payloadObject: [String: Any] = [
                "mobile_network_type": "unknown",
                "content": content,
                "nonce": nonce,
                "tts": false,
                "flags": 0,
                "attachments": [
                    [
                        "id": "0",
                        "filename": filename
                    ]
                ]
            ]
            
            if let messageReference = messageReference {
                payloadObject["message_reference"] = messageReference
            }
            
            let payloadData = try JSONSerialization.data(withJSONObject: payloadObject)
            guard let payloadJson = String(data: payloadData, encoding: .utf8) else {
                throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
            }
            
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            data.appendMultipartField(name: "payload_json", value: payloadJson, boundary: boundary)
            
            let fileData = try Data(contentsOf: fileUrl)
            data.appendFileField(
                name: "files[0]",
                filename: filename,
                mimeType: Self.mimeType(for: fileUrl),
                fileData: fileData,
                boundary: boundary
            )
            
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = data
        }
        
        return request
    }
    
    private static func mimeType(for fileURL: URL) -> String {
        if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = resourceValues.contentType,
           let mimeType = contentType.preferredMIMEType {
            return mimeType
        }
        
        if let contentType = UTType(filenameExtension: fileURL.pathExtension),
           let mimeType = contentType.preferredMIMEType {
            return mimeType
        }
        
        return "application/octet-stream"
    }
}

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendFileField(name: String, filename: String, mimeType: String, fileData: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}

extension DiscordRequest {
    static func sendMessage(channel: String, content: String, fileURL: URL? = nil, messageReference: [String: String]? = nil) -> SendMessage { .init(channel: channel, content: content, fileURL: fileURL, messageReference: messageReference) }
}


func generateDiscordNonce() -> String {
    let discordEpoch: Int64 = 1420070400000
    let unixMs = Int64(Date().timeIntervalSince1970 * 1000)
    let timestamp = unixMs - discordEpoch
    let randomBits = Int64.random(in: 0..<(1 << 22))
    let nonce = (timestamp << 22) | randomBits
    return String(nonce)
}
