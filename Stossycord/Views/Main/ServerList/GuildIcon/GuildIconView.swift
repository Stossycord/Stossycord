//
//  GuildIconView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI

struct GuildIconView: View {
    let iconURL: String?

    var body: some View {
        if let iconURL = iconURL, let url = URL(string: iconURL) {
            AsyncImage(url: url) { image in
                image.resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
            } placeholder: {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                    .overlay {
                        ProgressView()
                    }
                    .contextMenu {
                        Text("Image Loading or Failed to Load")
                    }
            }
        } else {
            Circle()
                .fill(Color.gray)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
        }
    }
}
