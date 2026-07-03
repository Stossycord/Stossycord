//
//  AuthorHeaderView.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import SwiftUI

struct AuthorHeaderView: View {
    let author: Author
    let editedTimestamp: String?
    let roleColor: Color
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if !isCurrentUser {
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
                
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
            }
        }
    }
}
