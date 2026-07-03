import Foundation

enum MessageBubbleStyle: String, CaseIterable, Identifiable {
    case `default`
    case imessage
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .imessage:
            return "iMessage-like"
        case .custom:
            return "Custom (JSON)"
        }
    }
}

enum DesignSettingsKeys {
    static let messageBubbleStyle = "messageBubbleStyle"
    static let showSelfAvatar = "showSelfAvatar"
    static let hideProfilePictures = "hideProfilePictures"
    static let customMessageBubbleJSON = "customMessageBubbleJSON"
    static let allowFakeNitroEmojis = "allowFakeNitroEmojis"
}
