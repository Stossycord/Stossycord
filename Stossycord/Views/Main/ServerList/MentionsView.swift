//
//  MentionsView.swift
//  Stossycord
//
//  Created by Stossy11 on 3/5/2026.
//


import SwiftUI

struct MentionsView: View {
    @ObservedObject private var userSession = CurrentUserService.shared
    @ObservedObject var webSocketService: WebSocketService
    
    @State private var navigateToChannel: MentionItem? = nil

    var body: some View {
        NavigationStack {
            Group {
                if userSession.mentions.isEmpty {
                    emptyState
                } else {
                    mentionsList
                }
            }
            .navigationTitle("Mentions")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !userSession.mentions.isEmpty {
                        Button("Mark all read") {
                            userSession.markAllMentionsRead()
                        }
                        .disabled(userSession.unreadMentionCount == 0)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "at.badge.plus")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("No mentions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("When someone @mentions you, it'll show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mentionsList: some View {
        List {
            ForEach(userSession.mentions) { mention in
                mentionRow(mention)
                    .onTapGesture {
                        userSession.markMentionRead(id: mention.id)
                        navigateToChannel = mention
                    }
                    .listRowBackground(
                        mention.isRead
                            ? Color.clear
                            : Color.accentColor.opacity(0.08)
                    )
            }
            .onDelete { indexSet in
                userSession.mentions.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.insetGrouped)
        .background(
            NavigationLink(
                destination: destinationView,
                isActive: Binding(
                    get: { navigateToChannel != nil },
                    set: { if !$0 { navigateToChannel = nil } }
                )
            ) { EmptyView() }
            .hidden()
        )
    }

    // MARK: - Row

    @ViewBuilder
    private func mentionRow(_ mention: MentionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if !mention.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }

                Text(mention.authorUsername)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(mention.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(mention.channelName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let guildName = mention.guildName {
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(guildName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Text(mention.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    

    @ViewBuilder
    private var destinationView: some View {
        if let mention = navigateToChannel {
            let guild = mention.guildId.flatMap { gid in
                userSession.Guilds.first(where: { $0.id == gid })
            }
            ChannelView(
                webSocketService: webSocketService,
                currentchannelname: mention.channelName,
                currentid: mention.channelId,
                currentGuild: guild
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

struct MentionBadge: ViewModifier {
    let count: Int

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: count)
            }
        }
    }
}

extension View {
    func mentionBadge(count: Int) -> some View {
        modifier(MentionBadge(count: count))
    }
}
