import SwiftUI
import Starscream

@main
struct YourApp: App {
    @StateObject var webSocketClient = WebSocketClient()
    @State var token = ""
    @State var username = "" 
    
    var body: some Scene {
        WindowGroup {
            NavView(webSocketClient: webSocketClient, token: token, username: username)
            // ContentSource(webSocketClient: webSocketClient)
        }
    }
}
