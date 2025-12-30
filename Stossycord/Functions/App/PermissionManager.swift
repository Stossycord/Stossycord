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

        let member: GuildMember = members.first { $0.user.id == currentUser.id } ??
            GuildMember(
                user: currentUser,
                roles: [guildId],
                joinedAt: "",
                deaf: false,
                mute: false,
                premiumSince: nil,
                nick: nil,
                pending: false,
                communicationDisabledUntil: nil
            )

        var permissions: UInt64 = 0

        if let everyoneRole = roles.first(where: { $0.id == guildId }),
           let perms = UInt64(everyoneRole.permissions) {
            permissions = perms
        }

        for role in roles where member.roles.contains(role.id) && role.id != guildId {
            if let perms = UInt64(role.permissions) {
                permissions |= perms
            }
        }

        if hasPermission(permissions, DiscordPermissions.ADMINISTRATOR) {
            return UInt64.max
        }

        func applyOverwrites(_ overwrites: [PermissionOverwrite]) {

            if let overwrite = overwrites.first(where: { $0.id == guildId }) {
                if let deny = UInt64(overwrite.deny) {
                    permissions &= ~deny
                }
                if let allow = UInt64(overwrite.allow) {
                    permissions |= allow
                }
            }

            let roleOverwrites = overwrites.filter {
                $0.type == 0 && member.roles.contains($0.id) && $0.id != guildId
            }

            for overwrite in roleOverwrites {
                if let deny = UInt64(overwrite.deny) {
                    permissions &= ~deny
                }
            }

            for overwrite in roleOverwrites {
                if let allow = UInt64(overwrite.allow) {
                    permissions |= allow
                }
            }

            if let overwrite = overwrites.first(where: {
                $0.type == 1 && $0.id == member.user.id
            }) {
                if let deny = UInt64(overwrite.deny) {
                    permissions &= ~deny
                }
                if let allow = UInt64(overwrite.allow) {
                    permissions |= allow
                }
            }
        }

        if let categoryOverwrites {
            applyOverwrites(categoryOverwrites)
        }

        if let channelOverwrites = channel?.permissionOverwrites {
            applyOverwrites(channelOverwrites)
        }

        if !hasPermission(permissions, DiscordPermissions.VIEW_CHANNEL) {
            return 0
        }

        return permissions
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
