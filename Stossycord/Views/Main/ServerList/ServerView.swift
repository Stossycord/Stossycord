//
//  ServersView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif
import SwiftUIIntrospect

var uiTabarController: UITabBarController?
var tabBarFrame: CGRect?

extension View {
    func tabBarHidden(_ hidden: Bool) -> some View {
        self.modifier(TabBarHiddenModifier(hidden: hidden))
    }
}

private struct TabBarHiddenModifier: ViewModifier {
    let hidden: Bool
    
    @State private var tabBarController: UITabBarController?
    @State private var originalFrame: CGRect?
    
    func body(content: Content) -> some View {
        content
            .introspect(.tabView) { (controller: UITabBarController) in
                if tabBarController == nil {
                    tabBarController = controller
                    originalFrame = controller.view.frame
                }
                applyHidden(hidden, to: controller)
            }
            .onChange(of: hidden) { newValue in
                guard let controller = tabBarController else { return }
                applyHidden(newValue, to: controller)
            }
            .onDisappear {
                guard let controller = tabBarController,
                      let frame = originalFrame else { return }
                controller.tabBar.isHidden = false
                controller.view.frame = frame
            }
    }

    private func applyHidden(_ hidden: Bool, to controller: UITabBarController) {
        guard let originalFrame else { return }
        controller.tabBar.isHidden = hidden
        controller.view.frame = hidden
            ? CGRect(
                x: originalFrame.origin.x,
                y: originalFrame.origin.y,
                width: originalFrame.width,
                height: originalFrame.height + controller.tabBar.frame.height
            ) : originalFrame
    }
}

struct ServerView: View {
    @State private var searchTerm = ""
    @Binding var guild: Guild?
    @EnvironmentObject var user: CurrentUserService
    @Environment(\.api) var discordAPI
    @StateObject var webSocketService: WebSocketService
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = true
    @AppStorage("allowDestructiveActions") private var allowDestructiveActions: Bool = false
    @State private var expandedFolders: Set<String> = []
    @State private var selectionMode = false
    @State private var selectedGuildIds: Set<String> = []
    @State private var showLeaveConfirmation = false
    @State private var isLeavingGuilds = false
    @State private var leaveErrorMessage: String?
    @State private var showLeaveErrorAlert = false
    @State private var channelNavigationRequest: ChatNavigationRequest?
    
    var body: some View {
        container
            #if !os(macOS) && !os(iOS)
            .confirmationDialog(
                "Leave selected servers?",
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    leaveSelectedGuilds()
                } label: {
                    Text(leaveConfirmationButtonTitle)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(leaveConfirmationMessage)
            }
#endif
            .alert(
                "Unable to Leave Servers",
                isPresented: $showLeaveErrorAlert,
                presenting: leaveErrorMessage
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
            #if os(macOS) || os(iOS)
            .onChange(of: showLeaveConfirmation) { shouldShow in
                if shouldShow {
                    presentLeaveConfirmation()
                }
            }
            #endif
            .onChange(of: selectionMode) { isSelecting in
                if !isSelecting {
                    selectedGuildIds.removeAll()
                }
            }
            .onChange(of: searchTerm) { _ in
                pruneSelections()
            }
            .onChange(of: useDiscordFolders) { _ in
                pruneSelections()
            }
            .onReceive(user.$Guilds) { _ in
                pruneSelections()
            }
            .onAppear {
                handleChatNavigationRequest(user.pendingChatNavigationRequest)
            }
            .onChange(of: user.pendingChatNavigationRequest) { request in
                handleChatNavigationRequest(request)
            }
    }
    
    @ViewBuilder
    private var container: some View {
        #if os(macOS)
        VStack {
            content()
        }
        #else
        if UIDevice.current.userInterfaceIdiom != .pad {
            NavigationStack {
                content()
            }
        } else {
            VStack {
                content()
            }
        }
        #endif
    }
    
    @ViewBuilder
    private func content() -> some View {
        VStack(spacing: 0) {
            // Search bar
            if UIDevice.current.userInterfaceIdiom != .pad {
                searchField
                    .navigationTitle("Servers")
            }
            
            // Server list
            serverList
        }
        .toolbar {
            
            selectionToolbar
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    NavigationLink(destination: MentionsView(webSocketService: .shared)) {
                        Image(systemName: "at")
                            .mentionBadge(count: user.unreadMentionCount)
                    }
                }
            }
        }
        .tabBarHidden(true)
        .background(guildNavigationLink)
  
    }

    @ViewBuilder
    private var guildNavigationLink: some View {
        if UIDevice.current.userInterfaceIdiom != .pad {
            NavigationLink(
                destination: guildNavigationDestination,
                isActive: Binding(
                    get: { channelNavigationRequest != nil },
                    set: { if !$0 { channelNavigationRequest = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    @ViewBuilder
    private var guildNavigationDestination: some View {
        if let request = channelNavigationRequest,
           let targetGuild = guild(for: request) {
            ChannelsListView(
                guild: targetGuild,
                webSocketService: webSocketService,
                initialNavigationRequest: request
            )
            .onAppear {
                guild = targetGuild
            }
        } else {
            EmptyView()
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search servers", text: $searchTerm)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchTerm.isEmpty {
                Button(action: { searchTerm = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    @State var showMentions: Bool = false
    
    private var serverList: some View {
        ScrollView {
            if UIDevice.current.userInterfaceIdiom == .pad {
                
                Button {
                    showMentions = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "at")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .mentionBadge(count: user.unreadMentionCount)
                }
                .buttonStyle(ServerRowButtonStyle())
                .sheet(isPresented: $showMentions, content: { MentionsView(webSocketService: .shared) })

            }
            
            LazyVStack(spacing: 12) {
                if useDiscordFolders {
                    ForEach(Array(organizedContent.enumerated()), id: \.element.id) { _, item in
                        switch item.type {
                        case .folder(let folder):
                            FolderView(
                                folder: folder,
                                guilds: item.guilds,
                                isExpanded: expandedFolders.contains(item.id),
                                onToggle: {
                                    if expandedFolders.contains(item.id) {
                                        expandedFolders.remove(item.id)
                                    } else {
                                        expandedFolders.insert(item.id)
                                    }
                                },
                                webSocketService: webSocketService,
                                selectionMode: selectionMode,
                                selectedGuildIds: selectedGuildIds,
                                onGuildSelected: { guild in
                                    toggleSelection(for: guild)
                                },
                                isLeavingGuilds: isLeavingGuilds
                            )
                        case .guild:
                            if let guild = item.guilds.first {
                                guildRow(for: guild)
                            }
                        }
                    }
                } else {
                    ForEach(filteredGuilds, id: \.id) { guild in
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            guildRow(for: guild)
                                .frame(maxWidth: 60)
                        } else {
                            guildRow(for: guild)
                        }
                    }
                }
                
                if filteredGuilds.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.15), value: selectionMode)
            .animation(.easeInOut(duration: 0.15), value: selectedGuildIds)
        }
        .scrollIndicatorsHidden()

    }
    
    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
#if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            if allowDestructiveActions {
                toolbarControls
            }
        }
#else
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if UIDevice.current.userInterfaceIdiom != .pad && allowDestructiveActions {
                toolbarControls
            }
        }
#endif
    }
    
    @ViewBuilder
    private var toolbarControls: some View {
        if selectionMode {
            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                Text("Leave")
            }
            .disabled(selectedGuildIds.isEmpty || isLeavingGuilds)
            
            if isLeavingGuilds {
                ProgressView()
                    .controlSize(.small)
            }
        }
        
        Button(selectionMode ? "Done" : "Select") {
            toggleSelectionMode()
        }
        .disabled(filteredGuilds.isEmpty && !selectionMode)
    }
    
    @ViewBuilder
    private func guildRow(for guild: Guild) -> some View {
        if selectionMode {
            Button {
                toggleSelection(for: guild)
            } label: {
                ServerRow(
                    guild: guild,
                    selectionMode: true,
                    isSelected: selectedGuildIds.contains(guild.id),
                    mentionCount: user.unreadMentionCount(guildId: guild.id)
                )
            }
            .disabled(isLeavingGuilds)
            .buttonStyle(ServerRowButtonStyle())
        } else {
            if UIDevice.current.userInterfaceIdiom != .pad {
                NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService).onAppear() { self.guild = guild } ) {
                    ServerRow(guild: guild, mentionCount: user.unreadMentionCount(guildId: guild.id))
                }
                .buttonStyle(ServerRowButtonStyle())
            } else {
                Button {
                    self.guild = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.guild = guild
                    }
                } label: {
                    ServerRow(guild: guild, mentionCount: user.unreadMentionCount(guildId: guild.id))
                }
                .buttonStyle(ServerRowButtonStyle())
            }
        }
    }

    private func handleChatNavigationRequest(_ request: ChatNavigationRequest?) {
        guard let request,
              !user.hasDMChannel(withId: request.mention.channelId),
              let targetGuild = guild(for: request) else { return }

        if UIDevice.current.userInterfaceIdiom == .pad {
            if guild?.id == targetGuild.id {
                guild = targetGuild
            } else {
                guild = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guild = targetGuild
                }
            }
        } else {
            channelNavigationRequest = request
        }
    }

    private func guild(for request: ChatNavigationRequest) -> Guild? {
        if let guildId = request.mention.guildId {
            return user.Guilds.first(where: { $0.id == guildId })
        }

        if let guildId = user.guildId(containing: request.mention.channelId) {
            return user.Guilds.first(where: { $0.id == guildId })
        }

        return nil
    }
    
    
    
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectionMode.toggle()
            if !selectionMode {
                selectedGuildIds.removeAll()
            }
        }
    }
    
    private func toggleSelection(for guild: Guild) {
        guard !guild.id.isEmpty else { return }
        if selectedGuildIds.contains(guild.id) {
            selectedGuildIds.remove(guild.id)
        } else {
            selectedGuildIds.insert(guild.id)
        }
    }
    
    private func pruneSelections() {
        let validIds = Set(filteredGuilds.map { $0.id })
        selectedGuildIds = selectedGuildIds.intersection(validIds)
    }
    
    @MainActor
    private func presentLeaveConfirmation() {
        guard !selectedGuildIds.isEmpty else {
            showLeaveConfirmation = false
            return
        }
#if os(macOS)
        let application = NSApplication.shared
        guard let window = application.keyWindow ?? application.mainWindow ?? application.windows.first else {
            showLeaveConfirmation = false
            return
        }
        let alert = NSAlert()
        alert.messageText = "Leave selected servers?"
        alert.informativeText = leaveConfirmationMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: leaveConfirmationButtonTitle)
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            Task { @MainActor in 
                showLeaveConfirmation = false
                if response == .alertFirstButtonReturn {
                    leaveSelectedGuilds()
                }
            }
        }
#elseif os(iOS)
        guard let presenter = resolvePresenterViewController() else {
            showLeaveConfirmation = false
            return
        }
        let alert = UIAlertController(
            title: "Leave selected servers?",
            message: leaveConfirmationMessage,
            preferredStyle: .alert
        )
        let confirmAction = UIAlertAction(title: leaveConfirmationButtonTitle, style: .destructive) { _ in
            leaveSelectedGuilds()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            showLeaveConfirmation = false
        }
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        alert.preferredAction = confirmAction
        presenter.present(alert, animated: true)
#else
        showLeaveConfirmation = false
#endif
    }

#if os(iOS)
    @MainActor
    private func resolvePresenterViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            return nil
        }
        return topViewController(from: root)
    }
    
    private func topViewController(from root: UIViewController?) -> UIViewController? {
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
#endif

    private func leaveSelectedGuilds() {
        showLeaveConfirmation = false
        let guildIds = Array(selectedGuildIds)
        guard !guildIds.isEmpty else { return }
        let token = user.token
        guard !token.isEmpty else {
            leaveErrorMessage = "Missing authentication token."
            showLeaveErrorAlert = true
            return
        }
        
        isLeavingGuilds = true
        
        let errors: [String] = []
        
        func finalize() {
            isLeavingGuilds = false
            if errors.isEmpty {
                selectionMode = false
            } else {
                leaveErrorMessage = errors.joined(separator: "\n")
                showLeaveErrorAlert = true
            }
        }
        
        func attemptLeave(guildId: String, attempt: Int) async {
            
            do {
                let _ = try await discordAPI.makeRequest(.leaveGuild, args: [guildId])
                
                removeGuildFromState(id: guildId)
                
            } catch {
                if let delay = retryDelay(for: error), attempt < 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        Task {
                            await attemptLeave(guildId: guildId, attempt: attempt + 1)
                        }
                    }
                }
            }
        }
        
        func processGuild(at index: Int) {
            guard index < guildIds.count else {
                finalize()
                return
            }
            let guildId = guildIds[index]
            
            Task {
                await attemptLeave(guildId: guildId, attempt: 1)
            }
        }

        processGuild(at: 0)
    }

    private func retryDelay(for error: Error) -> Double? {
        let nsError = error as NSError
        guard nsError.domain == "LeaveDiscordGuild", nsError.code == 429 else { return nil }
        if let data = nsError.userInfo["responseData"] as? Data, let value = parseRetryAfter(from: data) {
            return value + 0.2
        }
        if let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
           let data = message.data(using: .utf8),
           let value = parseRetryAfter(from: data) {
            return value + 0.2
        }
        return 2.2
    }
    
    private func parseRetryAfter(from data: Data) -> Double? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else { return nil }
        if let doubleValue = dictionary["retry_after"] as? Double {
            return doubleValue
        }
        if let intValue = dictionary["retry_after"] as? Int {
            return Double(intValue)
        }
        if let stringValue = dictionary["retry_after"] as? String {
            return Double(stringValue)
        }
        return nil
    }
    
    private func removeGuildFromState(id: String) {
        if let index = user.Guilds.firstIndex(where: { $0.id == id }) {
            user.Guilds.remove(at: index)
        }
        selectedGuildIds.remove(id)
    }
    
    private var selectedGuildsList: [Guild] {
        user.Guilds.filter { selectedGuildIds.contains($0.id) }
    }
    
    private var selectedGuildCount: Int {
        selectedGuildIds.count
    }
    
    private var leaveConfirmationButtonTitle: String {
        guard selectedGuildCount > 0 else { return "Leave Servers" }
        let noun = selectedGuildCount == 1 ? "Server" : "Servers"
        return "Leave \(selectedGuildCount) \(noun)"
    }
    
    private var leaveConfirmationMessage: String {
        let base = "This action can’t be undone."
        let summary = selectedGuildsSummary
        if summary.isEmpty {
            return "Are you sure you want to leave the selected servers? \(base)"
        } else {
            return "Are you sure you want to leave \(summary)? \(base)"
        }
    }
    
    private var selectedGuildsSummary: String {
        let names = selectedGuildsList.map(\.name)
        guard !names.isEmpty else { return "" }
        if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let prefix = names.prefix(3).joined(separator: ", ")
            return "\(prefix) and \(names.count - 3) more"
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchTerm.isEmpty ? "No servers available" : "No matching servers")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchTerm.isEmpty {
                Button("Clear Search") {
                    searchTerm = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    // MARK: - Logic
    
    private var filteredGuilds: [Guild] {
        user.Guilds.filter { guild in
            searchTerm.isEmpty || guild.name.localizedCaseInsensitiveContains(searchTerm)
        }
    }
    
    private var organizedContent: [ContentItem] {
        guard let guildFolders = user.userSettings?.guildFolders else {
            return filteredGuilds.map { ContentItem(id: $0.id, type: .guild, guilds: [$0]) }
        }
        
        var items: [ContentItem] = []
        var processedGuildIds: Set<String> = []
        
        for folder in guildFolders {
            let folderGuilds = folder.guildIds.compactMap { guildId in
                filteredGuilds.first { $0.id == guildId }
            }
            
            if !folderGuilds.isEmpty {
                if folder.id == nil && folderGuilds.count == 1 {
                    items.append(ContentItem(id: folderGuilds[0].id, type: .guild, guilds: folderGuilds))
                } else if folder.id != nil {
                    let folderId = String(folder.id ?? 0)
                    items.append(ContentItem(id: folderId, type: .folder(folder), guilds: folderGuilds))
                }
                
                folderGuilds.forEach { processedGuildIds.insert($0.id) }
            }
        }
        
        let unorganizedGuilds = filteredGuilds.filter { !processedGuildIds.contains($0.id) }
        unorganizedGuilds.forEach { guild in
            items.append(ContentItem(id: guild.id, type: .guild, guilds: [guild]))
        }
        
        return items
    }
}

// MARK: - Supporting Views

struct ServerRow: View {
    let guild: Guild
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var mentionCount: Int = 0
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            HStack(spacing: 14) {
                ServerIconView(iconURL: guild.iconUrl)
                    .mentionBadge(count: mentionCount)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        } else {
            HStack(spacing: 14) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                
                // Server icon
                ServerIconView(iconURL: guild.iconUrl)
                    .mentionBadge(count: selectionMode ? 0 : mentionCount)
                
                // Server name
                Text(guild.name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                if !selectionMode {
                    // Navigation indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
