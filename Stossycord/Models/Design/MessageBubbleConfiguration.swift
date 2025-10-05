import SwiftUI

struct MessageBubbleVisualConfiguration: Equatable {
    struct Side: Equatable {
        var background: Color
        var text: Color
        var stroke: Color?
    }
    
    struct PaddingSet: Equatable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat
        
        var edgeInsets: EdgeInsets {
            EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        }
    }
    
    var glassEffect: Bool
    var cornerRadius: CGFloat
    var strokeWidth: CGFloat
    var padding: PaddingSet
    var groupedVerticalPadding: CGFloat
    var ungroupedVerticalPadding: CGFloat
    var horizontalPadding: CGFloat
    var currentUser: Side
    var otherUser: Side
    
    static func resolve(style: MessageBubbleStyle, customJSON: String) -> MessageBubbleVisualConfiguration {
        switch style {
        case .default:
            return .defaultAppearance
        case .imessage:
            return .imessageAppearance
        case .custom:
            if let custom = CustomMessageBubbleConfiguration.decode(json: customJSON) {
                return MessageBubbleVisualConfiguration(custom: custom)
            }
            return .defaultAppearance
        }
    }
    
    private init(
        glassEffect: Bool,
        cornerRadius: CGFloat,
        strokeWidth: CGFloat,
        padding: PaddingSet,
        groupedVerticalPadding: CGFloat,
        ungroupedVerticalPadding: CGFloat,
        horizontalPadding: CGFloat,
        currentUser: Side,
        otherUser: Side
    ) {
        self.glassEffect = glassEffect
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.padding = padding
        self.groupedVerticalPadding = groupedVerticalPadding
        self.ungroupedVerticalPadding = ungroupedVerticalPadding
        self.horizontalPadding = horizontalPadding
        self.currentUser = currentUser
        self.otherUser = otherUser
    }
    
    private static let defaultPadding = PaddingSet(top: 12, leading: 12, bottom: 12, trailing: 12)
    
    private static let defaultCurrentSide = Side(
        background: .blue,
        text: .white,
        stroke: Color.blue.opacity(0.3)
    )
    
    private static let defaultOtherSide = Side(
        background: Color(red: 0.93, green: 0.94, blue: 0.96),
        text: .primary,
        stroke: Color.secondary.opacity(0.2)
    )
    
    private static let defaultAppearance = MessageBubbleVisualConfiguration(
        glassEffect: true,
        cornerRadius: 16,
        strokeWidth: 1,
        padding: defaultPadding,
        groupedVerticalPadding: 2,
        ungroupedVerticalPadding: 8,
        horizontalPadding: 4,
        currentUser: defaultCurrentSide,
        otherUser: defaultOtherSide
    )
    
    private static let imessageAppearance = MessageBubbleVisualConfiguration(
        glassEffect: true,
        cornerRadius: 18,
        strokeWidth: 0,
        padding: defaultPadding,
        groupedVerticalPadding: 0,
        ungroupedVerticalPadding: 6,
        horizontalPadding: 6,
        currentUser: Side(
            background: Color(red: 0.1, green: 0.5, blue: 1.0),
            text: .white,
            stroke: nil
        ),
        otherUser: Side(
            background: Color.gray,
            text: .primary,
            stroke: nil
        )
    )
}



private struct CustomMessageBubbleConfiguration: Codable {
    struct Side: Codable {
        var background: String?
        var text: String?
        var stroke: String?
    }
    
    struct Insets: Codable {
        var top: Double?
        var leading: Double?
        var bottom: Double?
        var trailing: Double?
    }
    
    var glassEffect: Bool?
    var cornerRadius: Double?
    var strokeWidth: Double?
    var padding: Insets?
    var groupedPadding: Double?
    var ungroupedPadding: Double?
    var horizontalPadding: Double?
    var currentUser: Side?
    var otherUser: Side?
    
    static func decode(json: String) -> CustomMessageBubbleConfiguration? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(CustomMessageBubbleConfiguration.self, from: data)
        } catch {
            return nil
        }
    }
}

private extension MessageBubbleVisualConfiguration {
    init(custom: CustomMessageBubbleConfiguration) {
        var base = MessageBubbleVisualConfiguration.defaultAppearance
        if let glassEffect = custom.glassEffect {
            base.glassEffect = glassEffect
        }
        if let cornerRadius = custom.cornerRadius {
            base.cornerRadius = CGFloat(cornerRadius)
        }
        if let strokeWidth = custom.strokeWidth {
            base.strokeWidth = CGFloat(strokeWidth)
        }
        if let grouped = custom.groupedPadding {
            base.groupedVerticalPadding = CGFloat(grouped)
        }
        if let ungrouped = custom.ungroupedPadding {
            base.ungroupedVerticalPadding = CGFloat(ungrouped)
        }
        if let horizontal = custom.horizontalPadding {
            base.horizontalPadding = CGFloat(horizontal)
        }
        if let padding = custom.padding {
            base.padding = MessageBubbleVisualConfiguration.PaddingSet(
                top: CGFloat(padding.top ?? Double(base.padding.top)),
                leading: CGFloat(padding.leading ?? Double(base.padding.leading)),
                bottom: CGFloat(padding.bottom ?? Double(base.padding.bottom)),
                trailing: CGFloat(padding.trailing ?? Double(base.padding.trailing))
            )
        }
        base.currentUser = MessageBubbleVisualConfiguration.resolve(side: base.currentUser, override: custom.currentUser)
        base.otherUser = MessageBubbleVisualConfiguration.resolve(side: base.otherUser, override: custom.otherUser)
        self = base
    }
    
    static func resolve(side: Side, override: CustomMessageBubbleConfiguration.Side?) -> Side {
        guard let override else { return side }
        var resolved = side
        if let backgroundHex = override.background, let color = Color(hex: backgroundHex) {
            resolved.background = color
        }
        if let textHex = override.text, let color = Color(hex: textHex) {
            resolved.text = color
        }
        if let strokeHex = override.stroke {
            resolved.stroke = Color(hex: strokeHex)
        }
        return resolved
    }
}

extension MessageBubbleVisualConfiguration {
        static func isCustomJSONValid(_ json: String) -> Bool {
                let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                return CustomMessageBubbleConfiguration.decode(json: trimmed) != nil
        }
    
        static let sampleJSON: String = """
        {
            "glassEffect": true,
            "cornerRadius": 18,
            "strokeWidth": 1,
            "padding": {
                "top": 12,
                "leading": 12,
                "bottom": 12,
                "trailing": 12
            },
            "groupedPadding": 2,
            "ungroupedPadding": 6,
            "horizontalPadding": 6,
            "currentUser": {
                "background": "#007AFF",
                "text": "#FFFFFF",
                "stroke": "#4DA3FF"
            },
            "otherUser": {
                "background": "#E5E5EA",
                "text": "#000000",
                "stroke": "#C7C7CC"
            }
        }
        """
}
