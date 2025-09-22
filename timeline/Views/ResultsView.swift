//
//  ResultsView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gameService = GameService.shared
    @State private var showCelebration = false
    
    var sortedPlayers: [Player] {
        gameService.players.sorted { p1, p2 in
            if p1.isEliminated != p2.isEliminated {
                return !p1.isEliminated
            }
            if p1.score != p2.score {
                return p1.score > p2.score
            }
            return p1.avgResponseMs < p2.avgResponseMs
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Résultats")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top)
                
                if let winner = sortedPlayers.first, !winner.isEliminated {
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                            .scaleEffect(showCelebration ? 1.3 : 1.0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.5)
                                .repeatCount(3, autoreverses: true),
                                value: showCelebration
                            )
                        
                        Text(winner.avatar ?? "🏆")
                            .font(.system(size: 80))
                        
                        Text(winner.displayName)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text("Vainqueur!")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                podiumIcon(for: index)
                                    .frame(width: 40)
                                
                                Text(player.avatar ?? "👤")
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(player.displayName)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 12) {
                                        Label("\(player.score) pts", systemImage: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                        
                                        if !player.isEliminated {
                                            Label("\(Int(player.avgResponseMs))ms", systemImage: "timer")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if player.isEliminated {
                                    Text("Éliminé")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.red.opacity(0.3))
                                        .clipShape(Capsule())
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding()
                            .background(backgroundForRank(index))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack(spacing: 16) {
                    Button(action: {
                        AudioHapticsService.shared.haptic(.medium)
                        gameService.leaveGame()
                        appState.navigateTo(.home)
                    }) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Accueil")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: {
                        AudioHapticsService.shared.haptic(.medium)
                        Task {
                            if let gameId = gameService.currentGame?.id {
                                gameService.leaveGame()
                                await appState.joinGame(gameId: gameId)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Rejouer")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2))
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white, lineWidth: 2)
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            showCelebration = true
            AudioHapticsService.shared.playVictory()
        }
    }
    
    private func podiumIcon(for index: Int) -> some View {
        Group {
            switch index {
            case 0:
                Image(systemName: "1.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
            case 1:
                Image(systemName: "2.circle.fill")
                    .foregroundStyle(.gray)
                    .font(.title2)
            case 2:
                Image(systemName: "3.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
            default:
                Text("#\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
    
    private func backgroundForRank(_ index: Int) -> some View {
        Group {
            switch index {
            case 0:
                LinearGradient(
                    colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case 1:
                LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case 2:
                LinearGradient(
                    colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            default:
                Color.white.opacity(0.1)
            }
        }
    }
}

#Preview {
    ResultsView()
        .environmentObject(AppState())
}