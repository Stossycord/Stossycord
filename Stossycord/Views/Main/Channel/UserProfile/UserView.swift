//
//  UserView.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import SwiftUI

struct UserView: View {
    var presence: Presence?
    var user: User
    var body: some View {
        HStack {
            AvatarView(author: Author(username: user.username, avatarHash: user.avatar, authorId: user.id), onProfileTap: nil)
            
            VStack(alignment: .leading) {
                Text(user.global_name ?? user.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let activity = presence?.activities?.first?.name {
                    Text(activity)
                        .font(.system(size: 12, weight: .light))
                }
            }
        }
    }
}
