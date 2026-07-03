import Foundation

class GetFavoriteGIFs: DiscordRequest<[FavoriteGIF]>, APIRequest {
    typealias Response = [FavoriteGIF]
    
    var endpoint: String = "users/@me/settings-proto/2"
    var method: String = "GET"
    
    var responseHandler: ((Data, URLResponse) -> [FavoriteGIF])? {
        { data, _ in
            guard let response = try? JSONDecoder().decode(UserSettingsProtoResponse.self, from: data) else {
                return Self.extractFavoriteGIFsFromJSON(data)
            }
            
            guard let protoData = response.decodedSettingsData else {
                return []
            }
            
            return FrecencyFavoriteGIFDecoder.decode(from: protoData)
        }
    }
    
    private static func extractFavoriteGIFsFromJSON(_ data: Data) -> [FavoriteGIF] {
        if let settings = try? JSONDecoder().decode(UserSettings.self, from: data),
           let gifs = settings.favoriteGIFs,
           !gifs.isEmpty {
            return gifs
        }
        
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        
        return Self.extractFavoriteGIFs(from: object)
    }
    
    private static func extractFavoriteGIFs(from object: Any, depth: Int = 0) -> [FavoriteGIF] {
        guard let dictionary = object as? [String: Any] else {
            if let array = object as? [Any] {
                for item in array {
                    let gifs = extractFavoriteGIFs(from: item, depth: depth + 1)
                    if !gifs.isEmpty { return gifs }
                }
            }
            return []
        }
        
        let keys = ["favorite_gifs", "favoriteGIFs", "favourite_gifs", "gif_favorites", "gifFavorites"]
        for key in keys {
            if let gifs = dictionary[key] as? [[String: Any]] {
                return decodeGIFs(from: gifs)
            }
            
            if let urls = dictionary[key] as? [String] {
                return urls.map { FavoriteGIF(url: $0) }
            }
            
            if let nested = dictionary[key] {
                let gifs = extractFavoriteGIFs(from: nested, depth: depth + 1)
                if !gifs.isEmpty {
                    return gifs
                }
            }
        }
        
        for nested in dictionary.values {
            let gifs = extractFavoriteGIFs(from: nested, depth: depth + 1)
            if !gifs.isEmpty { return gifs }
        }
        
        return []
    }
    
    private static func decodeGIFs(from dictionaries: [[String: Any]]) -> [FavoriteGIF] {
        let gifs: [FavoriteGIF] = dictionaries.compactMap { dictionary in
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
                return nil
            }
            
            return try? JSONDecoder().decode(FavoriteGIF.self, from: data)
        }
        
        return gifs
    }
}

private struct UserSettingsProtoResponse: Decodable {
    let settings: String
    
    var decodedSettingsData: Data? {
        var normalized = settings
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let padding = normalized.count % 4
        if padding > 0 {
            normalized.append(String(repeating: "=", count: 4 - padding))
        }
        
        return Data(base64Encoded: normalized)
    }
}

private enum FrecencyFavoriteGIFDecoder {
    static func decode(from data: Data) -> [FavoriteGIF] {
        var reader = ProtoReader(data)
        var gifs: [FavoriteGIF] = []
        
        do {
            while let field = try reader.readFieldHeader() {
                if field.number == 2 && field.wireType == 2 {
                    gifs.append(contentsOf: try decodeFavoriteGIFs(from: reader.readLengthDelimited()))
                } else {
                    try reader.skipField(wireType: field.wireType)
                }
            }
        } catch {
            return []
        }
        
        return gifs.sorted { lhs, rhs in
            let lhsOrder = lhs.order ?? Int.max
            let rhsOrder = rhs.order ?? Int.max
            
            if lhsOrder == rhsOrder {
                return lhs.id > rhs.id
            }
            
            return lhsOrder > rhsOrder
        }
    }
    
    private static func decodeFavoriteGIFs(from data: Data) throws -> [FavoriteGIF] {
        var reader = ProtoReader(data)
        var gifs: [FavoriteGIF] = []
        
        while let field = try reader.readFieldHeader() {
            if field.number == 1 && field.wireType == 2 {
                if let gif = try decodeGIFMapEntry(from: reader.readLengthDelimited()) {
                    gifs.append(gif)
                }
            } else {
                try reader.skipField(wireType: field.wireType)
            }
        }
        
        return gifs
    }
    
    private static func decodeGIFMapEntry(from data: Data) throws -> FavoriteGIF? {
        var reader = ProtoReader(data)
        var keyURL: String?
        var valueData: Data?
        
        while let field = try reader.readFieldHeader() {
            switch (field.number, field.wireType) {
            case (1, 2):
                keyURL = try reader.readString()
            case (2, 2):
                valueData = try reader.readLengthDelimited()
            default:
                try reader.skipField(wireType: field.wireType)
            }
        }
        
        guard let valueData else {
            return nil
        }
        
        return try decodeFavoriteGIF(from: valueData, fallbackURL: keyURL)
    }
    
    private static func decodeFavoriteGIF(from data: Data, fallbackURL: String?) throws -> FavoriteGIF? {
        var reader = ProtoReader(data)
        var src: String?
        var proxyURL: String?
        var width: Int?
        var height: Int?
        var order: Int?
        
        while let field = try reader.readFieldHeader() {
            switch (field.number, field.wireType) {
            case (1, 0):
                _ = try reader.readVarint()
            case (2, 2):
                src = try reader.readString()
            case (3, 0):
                width = Int(try reader.readVarint())
            case (4, 0):
                height = Int(try reader.readVarint())
            case (5, 0):
                order = Int(try reader.readVarint())
            default:
                if field.wireType == 2 {
                    let value = try reader.readString()
                    if value.isDiscordMediaProxyURL {
                        proxyURL = value
                    }
                } else {
                    try reader.skipField(wireType: field.wireType)
                }
            }
        }
        
        let previewURL = src ?? fallbackURL ?? proxyURL
        let sendURL = fallbackURL ?? src
        
        guard let url = sendURL else {
            return nil
        }
        
        return FavoriteGIF(
            id: fallbackURL ?? url,
            url: url,
            proxyURL: proxyURL ?? (src?.isDiscordMediaProxyURL == true ? src : nil),
            previewURL: previewURL,
            width: width,
            height: height,
            order: order
        )
    }
}

private struct ProtoReader {
    private let bytes: [UInt8]
    private var index = 0
    
    init(_ data: Data) {
        self.bytes = Array(data)
    }
    
    mutating func readFieldHeader() throws -> (number: Int, wireType: Int)? {
        guard index < bytes.count else { return nil }
        let key = try readVarint()
        return (Int(key >> 3), Int(key & 0x07))
    }
    
    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            
            shift += 7
            if shift >= 64 {
                throw ProtoReaderError.malformedVarint
            }
        }
        
        throw ProtoReaderError.truncated
    }
    
    mutating func readLengthDelimited() throws -> Data {
        let length = Int(try readVarint())
        guard length >= 0, index + length <= bytes.count else {
            throw ProtoReaderError.truncated
        }
        
        let start = index
        index += length
        return Data(bytes[start..<index])
    }
    
    mutating func readString() throws -> String {
        let data = try readLengthDelimited()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    mutating func skipField(wireType: Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            try advance(by: 8)
        case 2:
            _ = try readLengthDelimited()
        case 5:
            try advance(by: 4)
        default:
            throw ProtoReaderError.unsupportedWireType(wireType)
        }
    }
    
    private mutating func advance(by count: Int) throws {
        guard index + count <= bytes.count else {
            throw ProtoReaderError.truncated
        }
        index += count
    }
}

private enum ProtoReaderError: Error {
    case malformedVarint
    case truncated
    case unsupportedWireType(Int)
}

private extension String {
    var isDiscordMediaProxyURL: Bool {
        guard let host = URL(string: self)?.host?.lowercased() else { return false }
        return host == "media.discordapp.net" || host == "media.discordapp.com"
    }
}

extension DiscordRequest {
    static var favoriteGIFs: GetFavoriteGIFs { .init() }
}
