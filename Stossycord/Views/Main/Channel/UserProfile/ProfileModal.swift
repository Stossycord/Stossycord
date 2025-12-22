import SwiftUI
import KeychainSwift

struct ProfileModal: View {
    let userId: String
    let initialAuthor: Author?
    @Binding var isPresented: Bool
    
    @State private var profile: UserProfile?
    @State private var isLoading: Bool = true
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @StateObject private var webSocketService = WebSocketService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if let author = initialAuthor {
                    UserProfileView(
                        profile: profile,
                        author: author,
                        isLoading: isLoading,
                        currentUserId: webSocketService.currentUser.id
                    )
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading user profile...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Failed to Load Profile")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            fetchProfile()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("User not found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                if let profile = profile {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button {
                                #if os(iOS)
                                UIPasteboard.general.string = profile.user.id
                                #endif
                            } label: {
                                Label("Copy User ID", systemImage: "doc.on.doc")
                            }
                            
                            if let avatarUrl = profile.avatarUrl {
                                Button {
                                    #if os(iOS)
                                    UIPasteboard.general.string = avatarUrl
                                    #endif
                                } label: {
                                    Label("Copy Avatar URL", systemImage: "photo")
                                }
                            }
                            
                            if let bannerUrl = profile.bannerUrl {
                                Button {
                                    #if os(iOS)
                                    UIPasteboard.general.string = bannerUrl
                                    #endif
                                } label: {
                                    Label("Copy Banner URL", systemImage: "rectangle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchProfile()
        }
    }
    
    private func fetchProfile() {
        isLoading = true
        showError = false
        
        let keychain = KeychainSwift()
        guard let token = keychain.get("token") else {
            showError(message: "No authentication token found")
            return
        }
        
        getUserProfile(token: token, userId: userId) { fetchedProfile in
            Task { @MainActor in 
                isLoading = false
                if let fetchedProfile = fetchedProfile {
                    profile = fetchedProfile
                    CacheService.shared.setCachedUserProfile(fetchedProfile, userId: userId)
                } else {
                    getBasicUserInfo(token: token, userId: userId) { basicUser in
                        Task { @MainActor in 
                            if let user = basicUser {
                                let fallbackProfile = UserProfile(
                                    user: user,
                                    connectedAccounts: nil,
                                    premiumSince: nil,
                                    premiumType: nil,
                                    premiumGuildSince: nil,
                                    profileThemesExperimentBucket: nil,
                                    mutualGuilds: nil,
                                    mutualFriends: nil,
                                    userProfile: nil
                                )
                                profile = fallbackProfile
                            } else {
                                showError(message: "Unable to fetch user information")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        isLoading = false
    }
}
