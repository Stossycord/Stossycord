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

struct ServerView: View {
    @State private var searchTerm = ""
    @StateObject var webSocketService: WebSocketService
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = false
    @State private var expandedFolders: Set<String> = []
    @State private var selectionMode = false
    @State private var selectedGuildIds: Set<String> = []
    @State private var showLeaveConfirmation = false
    @State private var isLeavingGuilds = false
    @State private var leaveErrorMessage: String?
    @State private var showLeaveErrorAlert = false
    
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
            .onReceive(webSocketService.$Guilds) { _ in
                pruneSelections()
            }
    }
    
    @ViewBuilder
    private var container: some View {
        #if os(macOS)
        VStack {
            content()
        }
        #else
        NavigationStack {
            content()
        }
        #endif
    }
    
    @ViewBuilder
    private func content() -> some View {
            VStack(spacing: 0) {
                // Search bar
                searchField
                
                // Server list
                serverList
                    .onAppear {
                        webSocketService.currentguild = Guild(id: "", name: "", icon: "")
                    }
            }
            .navigationTitle("Servers")
            .toolbar {
                selectionToolbar
            }
            #if !os(macOS)
            .toolbar(.visible, for: .tabBar)
            #endif
    }
    
    // MARK: - Components
    
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
    
    private var serverList: some View {
        ScrollView {
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
                        guildRow(for: guild)
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
        .scrollIndicators(.hidden)
    }
    
    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            toolbarControls
        }
        #else
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            toolbarControls
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
                    isSelected: selectedGuildIds.contains(guild.id)
                )
            }
            .disabled(isLeavingGuilds)
            .buttonStyle(ServerRowButtonStyle())
        } else {
            NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                ServerRow(guild: guild)
            }
            .buttonStyle(ServerRowButtonStyle())
        }
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
            DispatchQueue.main.async {
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
        let token = webSocketService.token
        guard !token.isEmpty else {
            leaveErrorMessage = "Missing authentication token."
            showLeaveErrorAlert = true
            return
        }
        
        isLeavingGuilds = true
        let guildLookup = Dictionary(uniqueKeysWithValues: webSocketService.Guilds.map { ($0.id, $0.name) })
        var errors: [String] = []
        
        func finalize() {
            isLeavingGuilds = false
            if errors.isEmpty {
                selectionMode = false
            } else {
                leaveErrorMessage = errors.joined(separator: "\n")
                showLeaveErrorAlert = true
            }
        }
        
        func attemptLeave(guildId: String, attempt: Int, completion: @escaping (Result<Void, Error>) -> Void) {
            leaveDiscordGuild(token: token, guildId: guildId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        removeGuildFromState(id: guildId)
                        completion(.success(()))
                    case .failure(let error):
                        if let delay = retryDelay(for: error), attempt < 3 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptLeave(guildId: guildId, attempt: attempt + 1, completion: completion)
                            }
                        } else {
                            completion(.failure(error))
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
            attemptLeave(guildId: guildId, attempt: 1) { result in
                let nextIndex = index + 1
                switch result {
                case .success:
                    if nextIndex < guildIds.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            processGuild(at: nextIndex)
                        }
                    } else {
                        finalize()
                    }
                case .failure(let error):
                    let name = guildLookup[guildId] ?? guildId
                    errors.append("\(name): \(error.localizedDescription)")
                    if nextIndex < guildIds.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            processGuild(at: nextIndex)
                        }
                    } else {
                        finalize()
                    }
                }
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
        if let index = webSocketService.Guilds.firstIndex(where: { $0.id == id }) {
            webSocketService.Guilds.remove(at: index)
        }
        selectedGuildIds.remove(id)
        if webSocketService.currentguild.id == id {
            webSocketService.currentguild = Guild(id: "", name: "", icon: "")
            webSocketService.channels = []
            webSocketService.currentchannel = ""
        }
    }
    
    private var selectedGuildsList: [Guild] {
        webSocketService.Guilds.filter { selectedGuildIds.contains($0.id) }
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
        webSocketService.Guilds.filter { guild in
            searchTerm.isEmpty || guild.name.localizedCaseInsensitiveContains(searchTerm)
        }
    }
    
    private var organizedContent: [ContentItem] {
        guard let guildFolders = webSocketService.userSettings?.guildFolders else {
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
    
    var body: some View {
        HStack(spacing: 14) {
            if selectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            
            // Server icon
            ServerIconView(iconURL: guild.iconUrl)
            
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
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}


