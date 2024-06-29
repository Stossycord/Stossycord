//
//  MessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 17/5/2024.
//

import Giffy
import Foundation
import SwiftUI
import KeychainSwift

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let scale = width / size.width
        let newHeight = size.height * scale
        let newSize = CGSize(width: width, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

struct MessageView: View {
    let message: String
    let isEmoji: String
    let token: String
    @State private var downloadedImage: UIImage? = nil
    @State private var username: String = ""
    @State private var modifiedMessage = ""
    let keychain = KeychainSwift()

    var body: some View {
        let userIdPattern = "<@(\\d*)>"
        let emojiPattern = "<:[a-zA-Z0-9_]+:[0-9]+>"
        let gifemojipattern = "<a:(.*):(\\d*)>"
        let userIdRegex = try? NSRegularExpression(pattern: userIdPattern)
        let emojiRegex = try? NSRegularExpression(pattern: emojiPattern)
        let emoji2Regex = try? NSRegularExpression(pattern: gifemojipattern)
        let nsString = message as NSString
        let userIdMatches = userIdRegex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let emojiMatches = emojiRegex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let GifemojiMatches = emoji2Regex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var lastEnd = message.startIndex
        var views: [AnyView] = []
        
        switch isEmoji {
        case "yes":
            for match in emojiMatches {
                let range = Range(match.range, in: message)!
                let textRange = lastEnd..<range.lowerBound
                let text = String(message[textRange])
                
                var emojiId = String(message[range]).components(separatedBy: ":").last ?? ""
                emojiId = String(emojiId.dropLast())
                let imageUrl = "https://cdn.discordapp.com/emojis/\(emojiId).png?size=96"
                
                if !text.isEmpty {
                    views.append(AnyView(Text(text).font(.system(size: 18))))
                }
                
                lastEnd = range.upperBound
                let remainingTextRange = lastEnd..<message.endIndex
                let remainingText = String(message[remainingTextRange])
                
                
                if text.isEmpty && String(message[lastEnd..<message.endIndex]).isEmpty {
                    views.append(AnyView(AsyncImage(url: URL(string: imageUrl)) { image in
                        image.resizable()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .onAppear() {
                                print(emojiId)
                                print(imageUrl)
                            }
                    }))
                } else {
                    views.append(AnyView(AsyncImage(url: URL(string: imageUrl)) { image in
                        image.resizable()
                            .scaledToFit()
                            .frame(height: 18)
                    } placeholder: {
                        ProgressView()
                            .onAppear() {
                                print(emojiId)
                                print(imageUrl)
                            }
                    }))
                }
                
                if !remainingText.isEmpty {
                    views.append(AnyView(Text(remainingText).font(.system(size: 18))))
                }
                
            }
            
            
        
            
            /* if (!remainingText.isEmpty) {
                views.append(AnyView(Text(remainingText)))
            }
             */
            
            
            for match in userIdMatches {
                modifiedMessage = message
                let range = Range(match.range, in: message)!
                var userId = String(message[range]).dropFirst(2).dropLast()
                getUsernameFromDiscord(userId: String(userId), token: token) { result in
                    DispatchQueue.main.async {
                        if let username = result {
                            self.username = "@" + username
                            print("<@\(userId)>")
                            self.modifiedMessage = modifiedMessage.replacingOccurrences(of: "<@\(userId)>", with: self.username)
                            print(self.modifiedMessage)
                        }
                    }
                }
            }
        case "no":
            for match in GifemojiMatches {
                let range = Range(match.range, in: message)!
                let textRange = lastEnd..<range.lowerBound
                let text = String(message[textRange])
                var emojiId = String(message[range]).components(separatedBy: ":").last ?? ""
                emojiId = String(emojiId.dropLast())
                let imageUrl = "https://cdn.discordapp.com/emojis/\(emojiId).gif?size=96"
                let url = URL(string: imageUrl)
                
                views.append(AnyView(Text(text)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 18))
))
                
                views.append(AnyView(AsyncGiffy(url: url!) { phase in
                    switch phase {
                    case .loading:
                        ProgressView()
                    case .error:
                        Text("Failed to load GIF")
                    case .success(let giffy):
                        giffy
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .onAppear() {
                                print("giffff")
                            }
                    }
                }))
                lastEnd = range.upperBound
                
                let remainingTextRange = lastEnd..<message.endIndex
                let remainingText = String(message[remainingTextRange])
                views.append(AnyView(Text(remainingText)
                    .font(.system(size: 18))
                ))
            }
            
        case "userid":
            for match in userIdMatches {
                let range = Range(match.range, in: message)!
                let userId = String(message[range]).dropFirst(2).dropLast() // No need for var here
                getUsernameFromDiscord(userId: String(userId), token: token) { result in
                    if let username = result {
                        let usernameWithSymbol = "@" + username
                        print("<@\(userId)>")
                        modifiedMessage = message.replacingOccurrences(of: "<@\(userId)>", with: usernameWithSymbol)
                        print(modifiedMessage)
                    }
                }
            }
            
            views.append(AnyView(Text(modifiedMessage)
                .font(.system(size: 18))
            ))

        default:
            views.append(AnyView(Text(message)
                .font(.system(size: 18))
            ))
        }
        
        return HStack {
            ForEach(views.indices, id: \.self) { index in
                views[index]
            }
        }
    }
    
    private func downloadImage(from urlString: String) {
            guard let url = URL(string: urlString) else {
                return
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    return
                }

                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        downloadedImage = image
                    }
                }
            }.resume()
        }
    
    func getUsernameFromDiscord(userId: String, token: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://discord.com/api/v9/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.addValue("https://discord.com/channels/949183273383395328/958116619706564668", forHTTPHeaderField: "Referer")
        request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
        request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
        request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
        request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                completion(nil)
            } else if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let username = json["global_name"] as? String {
                            completion(username)
                            print("Username Aquired: " + username)
                        } else if let username = json["username"] as? String {
                            completion(username)
                            print("Username Aquired: " + username)
                        }
                    } else {
                        print("Invalid JSON")
                        completion(nil)
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}


