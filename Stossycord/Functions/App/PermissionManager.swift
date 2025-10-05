import Foundation

struct DiscordPermissions {
    static let SEND_MESSAGES: UInt64 = 1 << 11
    static let VIEW_CHANNEL: UInt64 = 1 << 10
    static let READ_MESSAGE_HISTORY: UInt64 = 1 << 16
    static let ATTACH_FILES: UInt64 = 1 << 15
    static let EMBED_LINKS: UInt64 = 1 << 14
    static let USE_EXTERNAL_EMOJIS: UInt64 = 1 << 18
    static let ADD_REACTIONS: UInt64 = 1 << 6
    static let MENTION_EVERYONE: UInt64 = 1 << 17
    static let MANAGE_MESSAGES: UInt64 = 1 << 13
    static let ADMINISTRATOR: UInt64 = 1 << 3
}

class PermissionManager {
    
    static func calculateChannelPermissions(
        currentUser: User,
        members: [GuildMember],
        roles: [AdvancedGuild.Role],
        channel: Channel?,
        guildId: String,
        categoryOverwrites: [PermissionOverwrite]? = nil
    ) -> UInt64 {
        // If no members loaded, create a temporary member with @everyone role
        var currentMember: GuildMember
        if let foundMember = members.first(where: { $0.user.id == currentUser.id }) {
            currentMember = foundMember
        } else {
            currentMember = GuildMember(
                user: currentUser,
                roles: [guildId], // @everyone role has same ID as guild ID
                joinedAt: "",
                deaf: false,
                mute: false,
                premiumSince: nil,
                nick: nil,
                pending: false,
                communicationDisabledUntil: nil
            )
        }
        
        var basePermissions: UInt64 = 0
        
        let userRoles = roles.filter { currentMember.roles.contains($0.id) }
        
        for role in userRoles {
            if let permissionInt = UInt64(role.permissions) {
                basePermissions |= permissionInt
            }
        }
        
        if userRoles.isEmpty, let everyoneRole = roles.first(where: { $0.id == guildId }) {
            if let permissionInt = UInt64(everyoneRole.permissions) {
                basePermissions |= permissionInt
            }
        }
        
        if hasPermission(basePermissions, DiscordPermissions.ADMINISTRATOR) {
            return UInt64.max
        }
        
        var finalPermissions = basePermissions

        if let categoryOverwrites {
            applyPermissionOverwrites(
                categoryOverwrites,
                guildId: guildId,
                currentMember: currentMember,
                finalPermissions: &finalPermissions
            )
        }

        guard let channel = channel else {
            return finalPermissions
        }

        if let overwrites = channel.permissionOverwrites {
            applyPermissionOverwrites(
                overwrites,
                guildId: guildId,
                currentMember: currentMember,
                finalPermissions: &finalPermissions
            )
        }

        return finalPermissions
    }
    
    static func canSendMessages(
        currentUser: User,
        members: [GuildMember],
        roles: [AdvancedGuild.Role],
        channel: Channel?,
        guildId: String
    ) -> Bool {
        if let currentMember = members.first(where: { $0.user.id == currentUser.id }),
           let disabledUntil = currentMember.communicationDisabledUntil,
           let disabledDate = parseISO8601Date(disabledUntil),
           disabledDate > Date() {
            print("user is timed out until \(disabledDate)")
            return false
        }
        
        let finalPermissions = calculateChannelPermissions(
            currentUser: currentUser,
            members: members,
            roles: roles,
            channel: channel,
            guildId: guildId
        )
        
        let canSend = hasPermission(finalPermissions, DiscordPermissions.SEND_MESSAGES)
        print("can send messages: \(canSend)")
        return canSend
    }
    
    static func canAttachFiles(
        currentUser: User,
        members: [GuildMember],
        roles: [AdvancedGuild.Role],
        channel: Channel?,
        guildId: String
    ) -> Bool {
        let finalPermissions = calculateChannelPermissions(
            currentUser: currentUser,
            members: members,
            roles: roles,
            channel: channel,
            guildId: guildId
        )
        
        let canAttach = hasPermission(finalPermissions, DiscordPermissions.ATTACH_FILES)
        print("can attach files: \(canAttach)")
        return canAttach
    }
    
    static func canViewChannel(
        currentUser: User,
        members: [GuildMember],
        roles: [AdvancedGuild.Role],
        channel: Channel,
        guildId: String,
        categoryOverwrites: [PermissionOverwrite]? = nil
    ) -> Bool {
        let finalPermissions = calculateChannelPermissions(
            currentUser: currentUser,
            members: members,
            roles: roles,
            channel: channel,
            guildId: guildId,
            categoryOverwrites: categoryOverwrites
        )
        
        let canView = hasPermission(finalPermissions, DiscordPermissions.VIEW_CHANNEL)
        return canView
    }
    
    static func getPermissionStatus(
        currentUser: User,
        members: [GuildMember],
        roles: [AdvancedGuild.Role],
        channel: Channel?,
        guildId: String
    ) -> ChannelPermissionStatus {
        
        if roles.isEmpty {
            return ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
        }
        
        let canSend = canSendMessages(
            currentUser: currentUser,
            members: members,
            roles: roles,
            channel: channel,
            guildId: guildId
        )
        
        let canAttach = canAttachFiles(
            currentUser: currentUser,
            members: members,
            roles: roles,
            channel: channel,
            guildId: guildId
        )
        
        
        var reasonMessage: String?
        
        if !canSend {
            if let currentMember = members.first(where: { $0.user.id == currentUser.id }),
               let disabledUntil = currentMember.communicationDisabledUntil,
               let disabledDate = parseISO8601Date(disabledUntil),
               disabledDate > Date() {
                reasonMessage = "You are timed out until \(formatDate(disabledDate))"
            } else {
                reasonMessage = "You do not have permission to send messages in this channel"
            }
        }
        
        return ChannelPermissionStatus(
            canSendMessages: canSend,
            canAttachFiles: canAttach,
            restrictionReason: reasonMessage
        )
    }
    
    private static func hasPermission(_ userPermissions: UInt64, _ permission: UInt64) -> Bool {
        return (userPermissions & permission) == permission
    }
    
    private static func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension PermissionManager {
    static func applyPermissionOverwrites(
        _ overwrites: [PermissionOverwrite],
        guildId: String,
        currentMember: GuildMember,
        finalPermissions: inout UInt64
    ) {
        if let everyoneOverwrite = overwrites.first(where: { $0.id == guildId }) {
            if let denyBits = UInt64(everyoneOverwrite.deny) {
                finalPermissions &= ~denyBits
            }
            if let allowBits = UInt64(everyoneOverwrite.allow) {
                finalPermissions |= allowBits
            }
        }

        let roleOverwrites = overwrites.filter { overwrite in
            overwrite.type == 0 && currentMember.roles.contains(overwrite.id) && overwrite.id != guildId
        }

        for roleOverwrite in roleOverwrites {
            if let denyBits = UInt64(roleOverwrite.deny) {
                finalPermissions &= ~denyBits
            }
        }

        for roleOverwrite in roleOverwrites {
            if let allowBits = UInt64(roleOverwrite.allow) {
                finalPermissions |= allowBits
            }
        }

        if let memberOverwrite = overwrites.first(where: { $0.id == currentMember.user.id && $0.type == 1 }) {
            if let denyBits = UInt64(memberOverwrite.deny) {
                finalPermissions &= ~denyBits
            }
            if let allowBits = UInt64(memberOverwrite.allow) {
                finalPermissions |= allowBits
            }
        }
    }
}

struct ChannelPermissionStatus {
    let canSendMessages: Bool
    let canAttachFiles: Bool
    let restrictionReason: String?
    
    var hasAnyRestriction: Bool {
        return !canSendMessages || !canAttachFiles
    }
}