//
//  StossycordmacOSApp.swift
//  StossycordmacOS
//
//  Created by Stossy11 on 28/5/2024.
//

import SwiftUI
import Foundation
import Starscream
import KeychainSwift


@main
struct StossycordmacOSApp: App {
    @StateObject var webSocketClient = WebSocketClient()
    var body: some Scene {
        WindowGroup {
            SidebarView(webSocketClient: webSocketClient)
        }
    }
}
