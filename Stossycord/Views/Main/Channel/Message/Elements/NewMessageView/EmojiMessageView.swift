//
//  EmojiMessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 17/1/2026.
//

import SwiftUI

struct EmojiMessageView: View {
    var url: URL
    
    private let emojiSize: CGFloat = 48
    
    var body: some View {
        if url.pathExtension == "gif" {
            AnimatedImageView(url: url)
                .aspectRatio(contentMode: .fill)
                .frame(width: emojiSize, height: emojiSize)
                .clipped()
        } else {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: emojiSize, height: emojiSize)
                    .clipped()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: emojiSize, height: emojiSize)
                    .overlay(ProgressView())
            }
        }
    }
}
