//
//  AppState.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI
import Combine
import Firebase

@MainActor
final class AppState: ObservableObject {
    @Published var currentView: AppView = .home
    @Published var colorScheme: ColorScheme? = nil
    @Published var pendingGameId: String?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    @AppStorage("userPreferredColorScheme") var userPreferredColorScheme: String = "system" {
        didSet {
            updateColorScheme()
        }
    }
    @AppStorage("soundEnabled") var soundEnabled: Bool = true {
        didSet {
            audioHapticsService.soundEnabled = soundEnabled
        }
    }
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true {
        didSet {
            audioHapticsService.hapticsEnabled = hapticsEnabled
        }
    }
    @AppStorage("playerDisplayName") var playerDisplayName: String = ""
    @AppStorage("lastPlayedGames") var lastPlayedGamesData: Data = Data()
    
    private let authService = AuthService.shared
    private let gameService = GameService.shared
    private let audioHapticsService = AudioHapticsService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        updateColorScheme()
        
        // Show home immediately
        currentView = .home
        
        // Don't authenticate until user needs it
    }
    
    private func setupBindings() {
        // Sync sound and haptics settings with service
        audioHapticsService.soundEnabled = soundEnabled
        audioHapticsService.hapticsEnabled = hapticsEnabled
        
        gameService.$error
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        authService.$error
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    private func updateColorScheme() {
        switch userPreferredColorScheme {
        case "light":
            colorScheme = .light
        case "dark":
            colorScheme = .dark
        default:
            colorScheme = nil
        }
    }
    
    private func authenticateUser() async {
        if !authService.isAuthenticated {
            do {
                try await authService.signInAnonymously()
            } catch {
                // Silently fail, user can still use the app
                print("Auth failed: \(error)")
            }
        }
    }
    
    func navigateTo(_ view: AppView) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentView = view
        }
    }
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.error = error
            self?.showError = true
        }
    }
    
    func dismissError() {
        self.showError = false
        self.error = nil
    }
    
    func createGame(mode: GameMode = .privateGame) async {
        await MainActor.run {
            isLoading = true
        }
        
        // Initialize Firebase if needed
        await ensureFirebaseAndAuth()
        
        do {
            let gameId: String
            if mode == .battleRoyale {
                gameId = try await gameService.joinBattleRoyale()
            } else {
                gameId = try await gameService.createGame(mode: mode)
            }
            
            await MainActor.run {
                navigateTo(.lobby)
                saveLastPlayedGame(gameId)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    func joinGame(gameId: String) async {
        print("🔵 AppState.joinGame called with: '\(gameId)'")
        
        // Validate input
        let trimmedId = gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            print("🔴 AppState.joinGame: Empty game ID")
            await MainActor.run {
                handleError(GameError.gameNotFound)
            }
            return
        }
        
        print("🔵 AppState.joinGame: Trimmed ID = '\(trimmedId)'")
        
        await MainActor.run {
            isLoading = true
        }
        
        // Initialize Firebase if needed
        await ensureFirebaseAndAuth()
        print("🔵 AppState.joinGame: Firebase initialized")
        
        do {
            // Use the new method that handles both short codes and full IDs
            try await gameService.joinGameByCode(trimmedId)
            print("🔵 AppState.joinGame: Successfully joined game")
            
            // Get the actual game ID for saving (access on MainActor)
            await MainActor.run {
                if let actualGameId = gameService.currentGame?.id {
                    print("🔵 AppState.joinGame: Navigating to lobby with game ID: \(actualGameId)")
                    navigateTo(.lobby)
                    saveLastPlayedGame(actualGameId)
                } else {
                    print("🔴 AppState.joinGame: No current game after joining?")
                }
            }
        } catch {
            print("🔴 AppState.joinGame: Error - \(error)")
            await MainActor.run {
                handleError(error)
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func ensureFirebaseAndAuth() async {
        // Authenticate if needed
        if !authService.isAuthenticated {
            await authenticateUser()
        }
    }
    
    func processDeepLink() async {
        guard let gameId = pendingGameId else { return }
        await joinGame(gameId: gameId)
        pendingGameId = nil
    }
    
    private func saveLastPlayedGame(_ gameId: String) {
        var games = getLastPlayedGames()
        games.removeAll { $0 == gameId }
        games.insert(gameId, at: 0)
        if games.count > 10 {
            games = Array(games.prefix(10))
        }
        
        if let encoded = try? JSONEncoder().encode(games) {
            lastPlayedGamesData = encoded
        }
    }
    
    func getLastPlayedGames() -> [String] {
        if let games = try? JSONDecoder().decode([String].self, from: lastPlayedGamesData) {
            return games
        }
        return []
    }
}

enum AppView {
    case loading
    case home
    case solo
    case lobby
    case game
    case results
    case settings
}
