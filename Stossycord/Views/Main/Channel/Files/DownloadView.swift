//
//  DownloadVIew.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//


import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif


struct DownloadView: View {
    let url: URL

    var body: some View {
        HStack {
            Text(url.lastPathComponent)
            Button(action: {
                // Open the URL in Safari
#if os(macOS)
                NSWorkspace.shared.open(url)
#else
                UIApplication.shared.open(url)
#endif
            }) {
                Image(systemName: "square.and.arrow.down.fill")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8.0)
    }
}
