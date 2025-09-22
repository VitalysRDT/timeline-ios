//
//  ContentView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Background color to ensure something is visible
            Color.blue.opacity(0.1)
                .ignoresSafeArea()
            
            switch appState.currentView {
            case .loading:
                LoadingView()
            case .home:
                HomeView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .solo:
                SoloGameView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .lobby:
                LobbyView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .game:
                GameView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .results:
                ResultsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case .settings:
                SettingsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.currentView)
        .alert("Erreur", isPresented: $appState.showError) {
            Button("OK") {
                appState.dismissError()
            }
        } message: {
            Text(appState.error?.localizedDescription ?? "Une erreur est survenue")
        }
        .task {
            if appState.pendingGameId != nil {
                await appState.processDeepLink()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
