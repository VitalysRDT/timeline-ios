//
//  LobbyView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI
import Combine

struct LobbyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gameService = GameService.shared
    @State private var timer: Timer?
    @State private var timeRemaining: Int = 30
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Button(action: {
                        AudioHapticsService.shared.haptic(.light)
                        gameService.leaveGame()
                        appState.navigateTo(.home)
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Quitter")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    if let gameId = gameService.currentGame?.id {
                        ShareLink(item: URL(string: "timeline://join?gameId=\(gameId)")!) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Inviter")
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
                
                VStack(spacing: 12) {
                    if gameService.currentGame?.mode == .battleRoyale {
                        HStack {
                            Image(systemName: "globe")
                            Text("Battle Royale")
                            Image(systemName: "flame.fill")
                        }
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    } else {
                        Text("Salle d'attente")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        if let shortCode = gameService.currentGame?.shortCode {
                            VStack(spacing: 8) {
                                Text("Code de la partie")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Text(shortCode)
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .onAppear {
                                        print("🟡 LobbyView: Displaying shortCode = '\(shortCode)'")
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(.white.opacity(0.3), lineWidth: 2)
                                            )
                                    )
                            }
                        }
                    }
                }
                
                // Show timer for Battle Royale, Start button for private games
                if gameService.currentGame?.mode == .battleRoyale {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 10)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(60 - min(timeRemaining, 60)) / 60)
                            .stroke(
                                LinearGradient(colors: [.white, .yellow], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timeRemaining)
                        
                        VStack {
                            Text("\(timeRemaining)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("secondes")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(
                            timeRemaining <= 5 ?
                            .spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true) :
                            .default,
                            value: pulseAnimation
                        )
                    }
                    .padding()
                } else {
                    // Private game: Show start button for host
                    if gameService.players.first(where: { $0.id == AuthService.shared.userId })?.isHost == true {
                        Button(action: {
                            Task {
                                AudioHapticsService.shared.haptic(.medium)
                                await gameService.startGame()
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Démarrer")
                            }
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                gameService.players.count >= 2 ?
                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                        .disabled(gameService.players.count < 2)
                        .padding()
                        
                        if gameService.players.count < 2 {
                            Text("Minimum 2 joueurs pour démarrer")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    } else {
                        // Non-host players see waiting message
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("En attente de l'hôte...")
                                .foregroundStyle(.white.opacity(0.8))
                                .font(.title3)
                        }
                        .padding()
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Joueurs")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("\(gameService.players.count)/\(gameService.currentGame?.maxPlayers ?? 8)")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(gameService.players) { player in
                                HStack {
                                    Text(player.avatar ?? "👤")
                                        .font(.title2)
                                    
                                    Text(player.displayName)
                                        .foregroundStyle(.white)
                                        .fontWeight(player.isHost ? .bold : .regular)
                                    
                                    Spacer()
                                    
                                    if player.isHost {
                                        Image(systemName: "crown.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                .padding()
                                .background(.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding()
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal)
                
                Spacer()
                
                if gameService.players.count < 2 {
                    Text("En attente d'autres joueurs...")
                        .foregroundStyle(.white.opacity(0.8))
                        .italic()
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: gameService.currentGame?.status) { oldValue, newValue in
            if newValue == .running {
                appState.navigateTo(.game)
            }
        }
        .onChange(of: timeRemaining) { oldValue, newValue in
            if newValue <= 5 {
                pulseAnimation = true
                AudioHapticsService.shared.playCountdownTick(secondsRemaining: newValue)
            }
        }
    }
    
    private func startTimer() {
        // Only start timer for Battle Royale mode
        if gameService.currentGame?.mode == .battleRoyale {
            if let startsAt = gameService.currentGame?.startsAt {
                let interval = startsAt.timeIntervalSinceNow
                timeRemaining = max(0, Int(interval))
            } else {
                timeRemaining = 60
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                updateTimeRemaining()
            }
        }
    }
    
    private func updateTimeRemaining() {
        // Only update for Battle Royale mode
        guard gameService.currentGame?.mode == .battleRoyale else { return }
        
        if let startsAt = gameService.currentGame?.startsAt {
            let remaining = Int(startsAt.timeIntervalSinceNow)
            timeRemaining = max(0, remaining)
            
            if timeRemaining == 0 && gameService.players.count >= 2 {
                Task {
                    await gameService.startGame()
                }
            }
        } else {
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else if gameService.players.count >= 2 {
                Task {
                    await gameService.startGame()
                }
            }
        }
    }
}

#Preview {
    LobbyView()
        .environmentObject(AppState())
}