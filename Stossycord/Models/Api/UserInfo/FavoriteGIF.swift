import Foundation

struct FavoriteGIF: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let proxyURL: String?
    let previewURL: String?
    let width: Int?
    let height: Int?
    let order: Int?

    var displayURL: URL? {
        preferredMediaURL(from: [previewURL, url, proxyURL])
    }

    var needsResolvedDisplayURL: Bool {
        displayURL?.isTenorPageURL == true
    }

    var sendURL: String {
        preferredMediaString(from: [url, previewURL, proxyURL]) ?? url
    }

    init(id: String? = nil, url: String, proxyURL: String? = nil, previewURL: String? = nil, width: Int? = nil, height: Int? = nil, order: Int? = nil) {
        self.id = id ?? url
        self.url = url
        self.proxyURL = proxyURL
        self.previewURL = previewURL
        self.width = width
        self.height = height
        self.order = order
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let url = try? container.decode(String.self) {
            self.init(url: url)
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        guard let url = Self.firstString(in: container, keys: [
            "url", "src", "gif_url", "gifUrl", "media_url", "mediaUrl",
            "image_url", "imageUrl", "tenor_url", "tenorUrl"
        ]) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Favorite GIF is missing a URL")
            )
        }

        let previewURL = Self.firstString(in: container, keys: [
            "preview_url", "previewUrl", "thumbnail_url", "thumbnailUrl",
            "thumb", "preview", "src"
        ])
        let proxyURL = Self.firstString(in: container, keys: [
            "proxy_url", "proxyUrl", "proxy_src", "proxySrc",
            "media_proxy_url", "mediaProxyUrl"
        ])

        let id = Self.firstString(in: container, keys: ["id", "gif_id", "gifId"])
        let width = Self.firstInt(in: container, keys: ["width", "w"])
        let height = Self.firstInt(in: container, keys: ["height", "h"])
        let order = Self.firstInt(in: container, keys: ["order"])

        self.init(id: id, url: url, proxyURL: proxyURL, previewURL: previewURL, width: width, height: height, order: order)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(url, forKey: .init("url"))
        try container.encodeIfPresent(proxyURL, forKey: .init("proxy_url"))
        try container.encodeIfPresent(previewURL, forKey: .init("preview_url"))
        try container.encodeIfPresent(width, forKey: .init("width"))
        try container.encodeIfPresent(height, forKey: .init("height"))
        try container.encodeIfPresent(order, forKey: .init("order"))
    }

    private static func firstString(in container: KeyedDecodingContainer<DynamicCodingKey>, keys: [String]) -> String? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try? container.decodeIfPresent(String.self, forKey: codingKey),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func firstInt(in container: KeyedDecodingContainer<DynamicCodingKey>, keys: [String]) -> Int? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try? container.decodeIfPresent(Int.self, forKey: codingKey) {
                return value
            }
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: codingKey),
               let value = Int(stringValue) {
                return value
            }
        }
        return nil
    }

    private func preferredMediaURL(from candidates: [String?]) -> URL? {
        preferredMediaString(from: candidates).flatMap(URL.init(string:))
    }

    private func preferredMediaString(from candidates: [String?]) -> String? {
        let validCandidates = candidates.compactMap { candidate -> String? in
            guard let candidate,
                  !candidate.isEmpty,
                  URL(string: candidate) != nil else {
                return nil
            }

            return candidate
        }

        return validCandidates.first { URL(string: $0)?.isLikelyVideoMediaURL != true }
            ?? validCandidates.first
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension URL {
    var isTenorPageURL: Bool {
        guard let host = host?.lowercased() else { return false }
        guard host == "tenor.com" || host.hasSuffix(".tenor.com") else { return false }

        let pathExtension = self.pathExtension.lowercased()
        return pathExtension.isEmpty || pathExtension == "html"
    }

    var isLikelyVideoMediaURL: Bool {
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "avi", "mkv", "flv", "wmv"]
        return videoExtensions.contains(pathExtension.lowercased())
    }
}
