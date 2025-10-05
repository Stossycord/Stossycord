import Foundation
import SwiftUI

class UserWrapper: NSObject {
    let user: User
    
    init(user: User) {
        self.user = user
    }
}

class UserProfileWrapper: NSObject {
    let profile: UserProfile
    
    init(profile: UserProfile) {
        self.profile = profile
    }
}

class CacheService: ObservableObject {
    static let shared = CacheService()
    
    @AppStorage("disableProfilePicturesCache") private var disableProfilePicturesCache: Bool = false
    @AppStorage("disableProfileCache") private var disableProfileCache: Bool = false
    
    private let profileCache = NSCache<NSString, UserWrapper>()
    private let fullProfileCache = NSCache<NSString, UserProfileWrapper>()
    private let profilePictureCache = NSCache<NSString, NSData>()
    
    private init() {
        profileCache.countLimit = 100
        fullProfileCache.countLimit = 50
        profilePictureCache.countLimit = 50
    }
    
    func getCachedUser(userId: String) -> User? {
        guard !disableProfileCache else { return nil }
        return profileCache.object(forKey: userId as NSString)?.user
    }
    
    func setCachedUser(_ user: User, userId: String) {
        guard !disableProfileCache else { return }
        profileCache.setObject(UserWrapper(user: user), forKey: userId as NSString)
    }
    
    func getCachedUserProfile(userId: String) -> UserProfile? {
        guard !disableProfileCache else { return nil }
        return fullProfileCache.object(forKey: userId as NSString)?.profile
    }
    
    func setCachedUserProfile(_ profile: UserProfile, userId: String) {
        guard !disableProfileCache else { return }
        fullProfileCache.setObject(UserProfileWrapper(profile: profile), forKey: userId as NSString)
    }
    
    func getCachedProfilePicture(url: String) -> Data? {
        guard !disableProfilePicturesCache else { return nil }
        return profilePictureCache.object(forKey: url as NSString) as Data?
    }
    
    func setCachedProfilePicture(_ data: Data, url: String) {
        guard !disableProfilePicturesCache else { return }
        profilePictureCache.setObject(data as NSData, forKey: url as NSString)
    }
    
    func clearProfileCache() {
        profileCache.removeAllObjects()
        fullProfileCache.removeAllObjects()
    }
    
    func clearProfilePictureCache() {
        profilePictureCache.removeAllObjects()
    }
    
    func clearAllCaches() {
        clearProfileCache()
        clearProfilePictureCache()
    }
    
    func getCacheSizeString() -> String {
        return "~2-10 MB"
    }
}
