// SettingsManager.swift
// made by sayborduu

import Foundation
import Combine

class SettingsManager: ObservableObject {
    @Published var userSettings: UserSettings?
    private var cancellables = Set<AnyCancellable>()
    
    init(webSocketService: WebSocketService) {
        webSocketService.$userSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.userSettings = settings
            }
            .store(in: &cancellables)
    }
    
    var isDeveloperMode: Bool {
        return userSettings?.developerMode ?? false
    }
    
    var currentTheme: String {
        return userSettings?.theme ?? "dark"
    }
    
    var isCompactMode: Bool {
        return userSettings?.messageDisplayCompact ?? false
    }
    
}