import Foundation

struct Poll: Codable, Hashable, Equatable {
    let question: PollQuestion?
    let answers: [PollAnswer]?
    let allowMultiselect: Bool?
    let expiry: String?
    let layoutType: Int?
    let duration: Int?
    var results: PollResults?

    enum CodingKeys: String, CodingKey {
        case question
        case answers
        case allowMultiselect = "allow_multiselect"
        case expiry
        case layoutType = "layout_type"
        case duration
        case results
    }
}

struct PollQuestion: Codable, Hashable, Equatable {
    let text: String?
}

struct PollAnswer: Codable, Hashable, Equatable {
    let answerId: Int
    let pollMedia: PollMedia?

    enum CodingKeys: String, CodingKey {
        case answerId = "answer_id"
        case pollMedia = "poll_media"
    }
}

struct PollMedia: Codable, Hashable, Equatable {
    let text: String?
    let emoji: PollEmoji?

    enum CodingKeys: String, CodingKey {
        case text
        case emoji
    }
}

struct PollEmoji: Codable, Hashable, Equatable {
    let id: String?
    let name: String?
    let animated: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case animated
    }
}

struct PollResults: Codable, Hashable, Equatable {
    let isFinalized: Bool?
    var totalVotes: Int?
    var answerCounts: [PollAnswerCount]?

    enum CodingKeys: String, CodingKey {
        case isFinalized = "is_finalized"
        case totalVotes = "total_votes"
        case answerCounts = "answer_counts"
    }
}

struct PollAnswerCount: Codable, Hashable, Equatable {
    let answerId: Int
    var count: Int?
    var meVoted: Bool?

    enum CodingKeys: String, CodingKey {
        case answerId = "id"
        case count
        case meVoted = "me_voted"
    }
}
