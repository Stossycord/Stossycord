//
//  DownloadVIew.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//


import SwiftUI
import UIKit


struct DownloadView: View {
    let url: URL

    var body: some View {
        HStack {
            Text(url.lastPathComponent)
            Button(action: {
                // Open the URL in Safari
                UIApplication.shared.open(url)
            }) {
                Image(systemName: "square.and.arrow.down.fill")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8.0)
    }
}
