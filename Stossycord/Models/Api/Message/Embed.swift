import Foundation

struct Embed: Codable, Hashable {
    let title: String?
    let type: String?
    let description: String?
    let url: String?
    let timestamp: String?
    let color: Int?
    let footer: EmbedFooter?
    let image: EmbedImage?
    let thumbnail: EmbedThumbnail?
    let video: EmbedVideo?
    let provider: EmbedProvider?
    let author: EmbedAuthor?
    let fields: [EmbedField]?

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case description
        case url
        case timestamp
        case color
        case footer
        case image
        case thumbnail
        case video
        case provider
        case author
        case fields
    }
}

struct EmbedFooter: Codable, Hashable {
    let text: String?
    let iconURL: String?
    let proxyIconURL: String?

    enum CodingKeys: String, CodingKey {
        case text
        case iconURL = "icon_url"
        case proxyIconURL = "proxy_icon_url"
    }
}

struct EmbedImage: Codable, Hashable {
    let url: String?
    let proxyURL: String?
    let height: Int?
    let width: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case proxyURL = "proxy_url"
        case height
        case width
    }
}

struct EmbedThumbnail: Codable, Hashable {
    let url: String?
    let proxyURL: String?
    let height: Int?
    let width: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case proxyURL = "proxy_url"
        case height
        case width
    }
}

struct EmbedVideo: Codable, Hashable {
    let url: String?
    let proxyURL: String?
    let height: Int?
    let width: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case proxyURL = "proxy_url"
        case height
        case width
    }
}

struct EmbedProvider: Codable, Hashable {
    let name: String?
    let url: String?
}

struct EmbedAuthor: Codable, Hashable {
    let name: String?
    let url: String?
    let iconURL: String?
    let proxyIconURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case iconURL = "icon_url"
        case proxyIconURL = "proxy_icon_url"
    }
}

struct EmbedField: Codable, Hashable {
    let name: String?
    let value: String?
    let isInline: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case isInline = "inline"
    }
}
