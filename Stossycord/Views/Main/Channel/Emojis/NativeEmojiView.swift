//
//  NativeEmojiView.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import SwiftUI

enum EmojiProvider: CaseIterable, Identifiable {
    case native
    case custom
    
    var id: String { self.name }
    
    var name: String {
        switch self {
        case .native:
            return "Native"
        case .custom:
            return "Custom"
        }
    }
}

struct NativeEmojiView: View {
    var guild: Guild?
    @StateObject var nativeEmojiHandler: PrivateEmojiHandler = .init()
    @ObservedObject private var userService = CurrentUserService.shared
    @State var provider: EmojiProvider = .native
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: NativeEmojiType?
    let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]
    
    var onTap: (Emoji?, NativeEmoji?) -> Void
    
    var body: some View {
        VStack {
            Picker("", selection: $provider) {
                ForEach(EmojiProvider.allCases) { emoji in
                    Text(emoji.name).tag(emoji)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            if userService.user?.hasNitro == true {
                switch provider {
                case .native:
                    nativeHandler
                case .custom:
                    EmojiView(guild: guild) { emoji in
                        onTap(emoji, nil)
                    }
                    .environmentObject(userService)
                }
            } else {
                nativeHandler
            }
        }
    }
    
    var nativeHandler: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)
            
            if searchText.isEmpty {
                categoryBar
                    .padding(.bottom, 8)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if searchText.isEmpty {
                            ForEach(NativeEmojiType.allCases) { emoji in
                                emojiSection(title: emoji, emojis: nativeEmojiHandler.getEmojisForType(emoji))
                                    .id(emoji)
                            }
                        } else {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(filteredEmojis) { emoji in
                                    Button {
                                        onTap(nil, emoji)
                                        dismiss()
                                    } label: {
                                        Text(emoji.emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 44, height: 44)
                                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedCategory) { newCategory in
                    guard let newCategory else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newCategory, anchor: .top)
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search emoji", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(NativeEmojiType.allCases) { type in
                    Button {
                        selectedCategory = type
                    } label: {
                        Image(systemName: type.icon)
                            .font(.system(size: 18))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(selectedCategory == type ? Color.accentColor : .secondary)
                            .background(
                                Circle()
                                    .fill(selectedCategory == type ? Color.accentColor.opacity(0.15) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var filteredEmojis: [NativeEmoji] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        
        return NativeEmojiType.allCases
            .flatMap { nativeEmojiHandler.getEmojisForType($0) }
            .filter { $0.searchableName.contains(query) }
    }
    
    private func emojiSection(title: NativeEmojiType, emojis: [NativeEmoji]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.displayName, systemImage: title.icon)
                .font(.headline)
                .lineLimit(1)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis) { emoji in
                    Button {
                        onTap(nil, emoji)
                        dismiss()
                    } label: {
                        Text(emoji.emoji)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}
