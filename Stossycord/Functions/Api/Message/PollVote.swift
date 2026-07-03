import Foundation

class PollVote: DiscordRequest<Bool>, APIRequest {
    typealias Response = Bool
    
    var endpoint: String = ""
    var method: String = "POST"
    
    var responseHandler: ((Data, URLResponse) -> Bool)? {
        { _, response in
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200..<300).contains(httpResponse.statusCode)
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let channel = args.first as? String,
              let messageId = args[safe: 1] as? String,
            let answerIds = args[safe: 2] as? [Int] else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        var request = makeUrlRequest(url: makeAPIUrl("channels/\(channel)/polls/\(messageId)/answers/@me"))
        let payload = ["answer_ids": answerIds]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        return request
    }
}

extension DiscordRequest {
    static var pollVote: PollVote { .init() }
}
