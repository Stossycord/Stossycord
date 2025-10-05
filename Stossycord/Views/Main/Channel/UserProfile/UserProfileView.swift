import SwiftUI

struct UserProfileView: View {
    let profile: UserProfile?
    let author: Author
    let isLoading: Bool
    let currentUserId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    if let profile = profile, let bannerUrl = profile.bannerUrl {
                        CachedAsyncImage(url: URL(string: bannerUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(height: 120)
                        }
                    } else {
                        let accentColor = profile?.accentColorHex ?? "#5865F2"
                        Rectangle()
                            .fill(Color(hex: accentColor) ?? .blue)
                            .frame(height: 120)
                    }
                    
                    HStack {
                        if let avatar = author.avatarHash {
                            CachedAsyncImage(url: URL(string: profile?.avatarUrl ?? "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemBackground), lineWidth: 4)
                                    )
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay(ProgressView())
                            }
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(author.username.prefix(1)))
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .offset(y: 40)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(profile?.displayName ?? author.globalName ?? author.username)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if profile?.hasNitro == true {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                        
                        Text(profile?.userTag ?? "@\(author.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let pronouns = profile?.userProfile?.pronouns?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !pronouns.isEmpty {
                            Text(pronouns)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    
                    if let profile = profile {
                        ProfileContentView(profile: profile, currentUserId: currentUserId)
                    } else if isLoading {
                        LoadingProfileView()
                    } else {
                        EmptyProfileView()
                    }
                    
                    Spacer(minLength: 20)
                }
            }
        }
    }
}

struct ProfileContentView: View {
    let profile: UserProfile
    let currentUserId: String?
    
    var isViewingOwnProfile: Bool {
        return currentUserId == profile.user.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bio = profile.userProfile?.bio ?? profile.user.bio, !bio.isEmpty {
                ProfileSectionView(title: "About Me") {
                    Text(bio)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if let connectedAccounts = profile.connectedAccounts, !connectedAccounts.isEmpty {
                ProfileSectionView(title: "Connections") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                        ForEach(connectedAccounts.prefix(6), id: \.id) { account in
                            ConnectedAccountView(account: account)
                        }
                    }
                }
            }
            
            if let mutualGuilds = profile.mutualGuilds, !mutualGuilds.isEmpty, !isViewingOwnProfile {
                ProfileSectionView(title: "\(mutualGuilds.count) Mutual Server\(mutualGuilds.count == 1 ? "" : "s")") {
                    Text("You share \(mutualGuilds.count) server\(mutualGuilds.count == 1 ? "" : "s") with this user")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if profile.user.bot == true {
                BotBadgeView()
            }
            
            UserIDView(userId: profile.user.id)
        }
        .padding(.horizontal, 20)
    }
}

struct ProfileSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ConnectedAccountView: View {
    let account: ConnectedAccount
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForService(account.type))
                .foregroundColor(colorForService(account.type))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(account.type.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if account.verified == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func iconForService(_ service: String) -> String {
        switch service.lowercased() {
        default: return "link"
        }
    }
    
    private func colorForService(_ service: String) -> Color {
        switch service.lowercased() {
        default: return .gray
        }
    }
}

struct BotBadgeView: View {
    var body: some View {
        HStack {
            Image(systemName: "gear")
                .foregroundColor(.blue)
            Text("Bot")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct UserIDView: View {
    let userId: String
    
    var body: some View {
        HStack {
            Text("User ID: \(userId)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Copy") {
                #if os(iOS)
                UIPasteboard.general.string = userId
                #endif
            }
            .font(.caption)
        }
    }
}

struct LoadingProfileView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

struct EmptyProfileView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("About Me")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This user hasn't added a bio yet.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }
}