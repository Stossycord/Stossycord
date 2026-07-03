import SwiftUI

struct ContentItem {
    let id: String
    let type: ContentType
    let guilds: [Guild]
    
    enum ContentType {
        case folder(UserSettings.GuildFolder)
        case guild
    }
}

struct FolderView: View {
    let folder: UserSettings.GuildFolder
    let guilds: [Guild]
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var webSocketService: WebSocketService
    let selectionMode: Bool
    let selectedGuildIds: Set<String>
    let onGuildSelected: (Guild) -> Void
    let isLeavingGuilds: Bool
    @EnvironmentObject var user: CurrentUserService
    
    private var mentionCount: Int {
        user.unreadMentionCount(guildIds: guilds.map(\.id))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button(action: onToggle) {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .mentionBadge(count: mentionCount)
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(ServerRowButtonStyle())
                .contextMenu {
                    Text(folder.name ?? "Folder")
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                }
            } else {
                Button(action: onToggle) {
                    HStack(spacing: 14) {
                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .mentionBadge(count: mentionCount)
                        
                        Text(folder.name ?? "Folder")
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(ServerRowButtonStyle())
            }
            
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(guilds, id: \.id) { guild in
                        if selectionMode {
                            Button {
                                onGuildSelected(guild)
                            } label: {
                                ServerRow(
                                    guild: guild,
                                    selectionMode: true,
                                    isSelected: selectedGuildIds.contains(guild.id),
                                    mentionCount: user.unreadMentionCount(guildId: guild.id)
                                )
                            }
                            .disabled(isLeavingGuilds)
                            .buttonStyle(ServerRowButtonStyle())
                        } else {
                            NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                                ServerRow(guild: guild, mentionCount: user.unreadMentionCount(guildId: guild.id))
                            }
                            .buttonStyle(ServerRowButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
