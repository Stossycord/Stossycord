//
//  ForumChannelView.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import SwiftUI

struct ForumChannelView: View {
    let webSocketService: WebSocketService
    let forumChannel: Channel
    let guild: Guild
    
    @Environment(\.api) private var discordAPI
    @ObservedObject private var user = CurrentUserService.shared
    @State private var fetchedPosts: [Channel] = []
    @State private var isLoadingPosts = false
    @State private var didLoadPosts = false
    
    private var posts: [Channel] {
        let storedPosts = user.threads(forParent: forumChannel.id)
        let combined = storedPosts + fetchedPosts
        var uniquePosts: [String: Channel] = [:]
        
        for post in combined where post.isThread {
            uniquePosts[post.id] = post
        }
        
        return uniquePosts.values.sorted { lhs, rhs in
            snowflake(lhs.lastMessageId ?? lhs.id) > snowflake(rhs.lastMessageId ?? rhs.id)
        }
    }
    
    private var activePosts: [Channel] {
        posts.filter { $0.threadMetadata?.archived != true }
    }
    
    private var olderPosts: [Channel] {
        posts.filter { $0.threadMetadata?.archived == true }
    }
    
    var body: some View {
        List {
            if posts.isEmpty {
                Text(isLoadingPosts ? "Loading posts..." : "No posts available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activePosts, id: \.id) { post in
                    forumPostLink(post)
                }
                
                if !olderPosts.isEmpty {
                    Section("Older Posts") {
                        ForEach(olderPosts, id: \.id) { post in
                            forumPostLink(post)
                        }
                    }
                }
            }
        }
        .navigationTitle(forumChannel.displayName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task(id: forumChannel.id) {
            await loadPosts()
        }
    }
    
    private func forumPostLink(_ post: Channel) -> some View {
        NavigationLink {
            ChannelView(
                webSocketService: webSocketService,
                currentchannelname: post.displayName,
                currentid: post.id,
                currentGuild: guild
            )
            .ignoresSafeArea(.container, edges: .bottom)
        } label: {
            forumPostRow(post)
        }
    }
    
    private func forumPostRow(_ post: Channel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: post.threadMetadata?.archived == true ? "archivebox" : "text.bubble")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let count = post.messageCount {
                        Label("\(count)", systemImage: "bubble.left")
                    }
                    
                    if post.threadMetadata?.archived == true {
                        Label("Archived", systemImage: "archivebox")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    @MainActor
    private func loadPosts() async {
        guard !user.token.isEmpty, !didLoadPosts else { return }
        
        isLoadingPosts = true
        defer {
            isLoadingPosts = false
            didLoadPosts = true
        }
        
        async let activePosts = fetchActivePosts()
        async let archivedPosts = fetchArchivedPosts()
        let (active, archived) = await (activePosts, archivedPosts)
        let posts = active + archived
        
        fetchedPosts = uniquePosts(from: posts)
        
        for post in fetchedPosts {
            user.upsertThread(post, parentId: forumChannel.id)
        }
    }
    
    private func fetchActivePosts() async -> [Channel] {
        let response: ForumPostsResponse? = try? await discordAPI.makeRequest(.activeThreads, args: [guild.id])
        return response?.threads.filter { $0.parentId == forumChannel.id } ?? []
    }
    
    private func fetchArchivedPosts() async -> [Channel] {
        var allPosts: [Channel] = []
        var offset = 0
        var hasMore = true
        
        while hasMore {
            let response: ForumPostsResponse? = try? await discordAPI.makeRequest(.forumPosts, args: [forumChannel.id, offset])
            let posts = response?.threads.filter { $0.parentId == forumChannel.id } ?? []
            
            allPosts.append(contentsOf: posts)
            hasMore = response?.hasMore == true && !posts.isEmpty
            offset += 25
        }
        
        return allPosts
    }
    
    private func uniquePosts(from posts: [Channel]) -> [Channel] {
        var uniquePosts: [String: Channel] = [:]
        
        for post in posts where post.isThread {
            uniquePosts[post.id] = post
        }
        
        return uniquePosts.values.sorted { lhs, rhs in
            snowflake(lhs.lastMessageId ?? lhs.id) > snowflake(rhs.lastMessageId ?? rhs.id)
        }
    }
    
    private func snowflake(_ id: String?) -> UInt64 {
        guard let id, let value = UInt64(id) else { return 0 }
        return value
    }
}
