//
//  GameView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI
import UIKit

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gameService = GameService.shared
    @State private var selectedInsertIndex: Int? = nil
    @State private var timeRemaining: Int = 30
    @State private var timer: Timer?
    @State private var hasSubmitted = false
    @State private var showErrorAnimation = false
    @State private var isEliminated = false
    @State private var wrongCardIds: Set<String> = []
    
    private var userId: String? {
        AuthService.shared.userId
    }
    
    private var myLives: Int {
        if let userId = userId {
            return gameService.playerLives[userId] ?? 3
        }
        return 3
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                gameHeader
                
                if !isEliminated && myLives > 0 {
                    // Active player view
                    if let card = gameService.currentCard, !hasSubmitted {
                        currentCardView(card: card)
                    } else if hasSubmitted {
                        waitingView
                    } else {
                        // Pas de carte disponible
                        VStack {
                            ProgressView()
                            Text("En attente de la carte...")
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                } else {
                    // Spectator view for eliminated players
                    spectatorView
                }
                
                Spacer(minLength: 10)
                
                timelineView
                
                Spacer(minLength: 10)
                
                playersStatusView
            }
        }
        .onAppear {
            print("🎮 GameView appeared")
            startRoundTimer()
            checkEliminationStatus()
        }
        .onChange(of: gameService.currentRound) { oldRound, newRound in
            print("🔄 Round changed: old=\(oldRound?.roundIndex ?? -1), new=\(newRound?.roundIndex ?? -1)")
            if newRound != nil && newRound?.roundIndex != oldRound?.roundIndex {
                print("🆕 New round started: \(newRound?.roundIndex ?? -1)")
                // New round started
                hasSubmitted = false
                selectedInsertIndex = nil
                startRoundTimer()
            }
        }
        .onChange(of: gameService.currentCard) { oldCard, newCard in
            print("🃏 Card changed: old=\(oldCard?.title ?? "nil"), new=\(newCard?.title ?? "nil")")
        }
        .onChange(of: gameService.timeline.count) { oldCount, newCount in
            print("📊 Timeline changed: \(oldCount) -> \(newCount) cards")
        }
        .onChange(of: myLives) { _, lives in
            if lives <= 0 {
                isEliminated = true
            }
        }
    }
    
    private var gameHeader: some View {
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
            
            // Timer
            HStack {
                Image(systemName: "timer")
                Text("\(timeRemaining)s")
                    .font(.headline)
                    .monospacedDigit()
            }
            .foregroundStyle(timeRemaining <= 10 ? .red : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
            
            Spacer()
            
            // Lives
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < myLives ? "heart.fill" : "heart")
                        .foregroundStyle(index < myLives ? .red : .white.opacity(0.3))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func currentCardView(card: Card) -> some View {
        let metrics = layoutMetrics
        let cardPanelWidth = max(metrics.cardWidth + 80, horizontalSizeClass == .regular ? 360 : 260)
        let verticalSpacing: CGFloat = horizontalSizeClass == .regular ? 20 : 16
        
        return VStack(spacing: verticalSpacing) {
            Text("Placez cette carte dans la timeline")
                .font(.system(size: horizontalSizeClass == .regular ? 22 : 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            
            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 16 : 12) {
                Text(card.title)
                    .font(.system(size: horizontalSizeClass == .regular ? 26 : 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                } else if let hint = card.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                }
                
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: card.category.color) ?? .blue)
                        .frame(width: 10, height: 10)
                    Text(card.category.displayName)
                        .font(.system(size: horizontalSizeClass == .regular ? 15 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, horizontalSizeClass == .regular ? 28 : 22)
            .padding(.horizontal, horizontalSizeClass == .regular ? 30 : 24)
            .frame(width: cardPanelWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 26 : 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                (Color(hex: card.category.color) ?? .blue).opacity(0.9),
                                (Color(hex: card.category.color) ?? .blue).opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 26 : 22)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: horizontalSizeClass == .regular ? 14 : 10, x: 0, y: horizontalSizeClass == .regular ? 12 : 8)
            .scaleEffect(showErrorAnimation ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: showErrorAnimation)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
    }

    private var waitingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("En attente des autres joueurs...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding()
    }
    
    private var spectatorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.5))
            
            Text("Vous êtes éliminé")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("Vous pouvez continuer à observer la partie")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var timelineView: some View {
        let metrics = layoutMetrics
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.horizontalSpacing) {
                ForEach(0...gameService.timeline.count, id: \.self) { index in
                    HStack(spacing: metrics.horizontalSpacing) {
                        insertButton(at: index)
                        
                        if index < gameService.timeline.count {
                            let card = gameService.timeline[index]
                            TimelineCardView(
                                card: card,
                                isWrong: wrongCardIds.contains(card.id),
                                isCompactLayout: metrics.isCompact
                            )
                            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: metrics.cardWidth)
                        }
                    }
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .frame(height: metrics.timelineHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            showErrorAnimation ?
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red, lineWidth: 3)
                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: showErrorAnimation) :
            nil
        )
        .padding(.horizontal)
    }

    private var layoutMetrics: TimelineLayoutMetrics {
        let isRegular = horizontalSizeClass == .regular
        let timelineCount = max(gameService.timeline.count, 1)
        let screenWidth = UIScreen.main.bounds.width
        let reservedEdges = isRegular ? 320.0 : 140.0
        let availableWidth = max(240.0, screenWidth - reservedEdges)
        let targetVisible = isRegular ? max(min(timelineCount + 2, 8), 5) : max(min(timelineCount + 1, 5), 3)
        let rawCardWidth = availableWidth / CGFloat(targetVisible)
        let minWidth: CGFloat = isRegular ? 180 : 130
        let maxWidth: CGFloat = isRegular ? 240 : 170
        let cardWidth = min(max(rawCardWidth, minWidth), maxWidth)
        let cardHeight: CGFloat = isRegular ? 240 : 190
        let horizontalSpacing: CGFloat = isRegular ? 28 : 16
        let horizontalPadding: CGFloat = isRegular ? 34 : 18
        let verticalPadding: CGFloat = isRegular ? 26 : 14
        let timelineHeight = cardHeight + verticalPadding * 2
        let insertButtonWidth = isRegular ? max(86, cardWidth * 0.3) : 64
        let insertButtonHeight = cardHeight
        let isCompact = cardWidth < 170
        return TimelineLayoutMetrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            horizontalSpacing: horizontalSpacing,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            timelineHeight: timelineHeight,
            insertButtonWidth: insertButtonWidth,
            insertButtonHeight: insertButtonHeight,
            isCompact: isCompact
        )
    }

    private func insertButton(at index: Int) -> some View {
        let metrics = layoutMetrics
        let positionLabel: String
        if index == 0 {
            positionLabel = "Début"
        } else if index == gameService.timeline.count {
            positionLabel = "Fin"
        } else {
            positionLabel = "#\(index)"
        }
        
        return Button {
            if !hasSubmitted && !isEliminated && myLives > 0 {
                print("🎯 Insert button tapped at index \(index)")
                selectPosition(index)
            }
        } label: {
            VStack(spacing: metrics.isCompact ? 10 : 14) {
                Image(systemName: selectedInsertIndex == index ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: metrics.isCompact ? 22 : 28, weight: .semibold))
                    .foregroundStyle(selectedInsertIndex == index ? Color.green : Color.white.opacity(0.85))
                
                Text(positionLabel)
                    .font(.system(size: metrics.isCompact ? 12 : 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: metrics.insertButtonWidth, height: metrics.insertButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedInsertIndex == index ? Color.green : Color.white.opacity(0.25),
                        style: StrokeStyle(lineWidth: selectedInsertIndex == index ? 2.4 : 1.2, dash: selectedInsertIndex == index ? [] : [6, 6])
                    )
            )
            .shadow(color: Color.black.opacity(selectedInsertIndex == index ? 0.35 : 0.18), radius: selectedInsertIndex == index ? 9 : 4, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedInsertIndex == index ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedInsertIndex == index)
    }

    private var playersStatusView: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(gameService.players, id: \.id) { player in
                    PlayerStatusView(
                        player: player,
                        lives: gameService.playerLives[player.id ?? ""] ?? 0,
                        hasSubmitted: hasPlayerSubmitted(player),
                        isCurrentPlayer: player.id == userId
                    )
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.1))
    }
    
    private func selectPosition(_ index: Int) {
        guard !hasSubmitted else {
            print("⚠️ Already submitted, ignoring selection")
            return
        }
        
        print("✅ Position selected: \(index)")
        selectedInsertIndex = index
        AudioHapticsService.shared.haptic(.selection)
        
        // Auto-submit after selection
        Task {
            await submitPlacement()
        }
    }
    
    private func submitPlacement() async {
        guard let index = selectedInsertIndex,
              !hasSubmitted else {
            print("❌ Cannot submit: index=\(selectedInsertIndex?.description ?? "nil"), hasSubmitted=\(hasSubmitted)")
            return
        }
        
        print("📤 Submitting placement at index \(index)")
        hasSubmitted = true
        let currentCardId = gameService.currentCard?.id
        
        do {
            try await gameService.submitPlacement(positionIndex: index)
            print("✅ Placement submitted successfully")
            
            // Check if placement was correct
            if let card = gameService.currentCard {
                let isCorrect = validatePlacement(card: card, at: index)
                print("🎯 Placement was \(isCorrect ? "CORRECT" : "WRONG")")
                
                if !isCorrect {
                    showErrorAnimation = true
                    AudioHapticsService.shared.playCardPlacement(isCorrect: false)
                    
                    // Mark card as wrong
                    if let cardId = currentCardId {
                        wrongCardIds.insert(cardId)
                    }
                    
                    // Reset animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showErrorAnimation = false
                    }
                } else {
                    AudioHapticsService.shared.playCardPlacement(isCorrect: true)
                    // Remove from wrong cards if it was there
                    if let cardId = currentCardId {
                        wrongCardIds.remove(cardId)
                    }
                }
            }
            
        } catch {
            print("❌ Failed to submit placement: \(error)")
            hasSubmitted = false
        }
    }
    
    private func validatePlacement(card: Card, at index: Int) -> Bool {
        let timeline = gameService.timeline
        
        if timeline.isEmpty {
            return true
        }
        
        if index == 0 {
            return card.isBefore(timeline[0])
        } else if index == timeline.count {
            return card.isAfter(timeline[timeline.count - 1])
        } else {
            return card.isBetween(timeline[index - 1], timeline[index])
        }
    }
    
    private func hasPlayerSubmitted(_ player: Player) -> Bool {
        guard let round = gameService.currentRound,
              let playerId = player.id else { return false }
        
        return gameService.submissions.contains { submission in
            submission.playerId == playerId && submission.roundIndex == round.roundIndex
        }
    }
    
    private func startRoundTimer() {
        timer?.invalidate()
        
        guard let round = gameService.currentRound else {
            print("⏰ No current round to start timer for")
            return
        }
        
        print("⏰ Starting timer for round \(round.roundIndex)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let remaining = Int(round.roundEndsAt.timeIntervalSinceNow)
            timeRemaining = max(0, remaining)
            
            if timeRemaining <= 0 {
                print("⏰ Timer expired!")
                timer?.invalidate()
                
                // Auto-submit if not submitted
                if !hasSubmitted && !isEliminated && myLives > 0 {
                    print("⏰ Auto-submitting random position")
                    Task { @MainActor in
                        // Submit random position
                        selectedInsertIndex = Int.random(in: 0...gameService.timeline.count)
                        await submitPlacement()
                    }
                }
            }
        }
    }
    
    private func checkEliminationStatus() {
        if let userId = userId {
            isEliminated = gameService.playerLives[userId] ?? 3 <= 0
        }
    }
}

struct PlayerStatusView: View {
    let player: Player
    let lives: Int
    let hasSubmitted: Bool
    let isCurrentPlayer: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(player.avatar ?? "🎮")
                .font(.title2)
            
            Text(player.displayName)
                .font(.caption2)
                .lineLimit(1)
            
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < lives ? "heart.fill" : "heart")
                        .font(.caption2)
                        .foregroundStyle(index < lives ? .red : .gray)
                }
            }
            
            if hasSubmitted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 80, height: 80)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentPlayer ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentPlayer ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .opacity(lives > 0 ? 1.0 : 0.5)
    }
}

// Timeline card view for multiplayer

    private struct TimelineLayoutMetrics {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let horizontalSpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let timelineHeight: CGFloat
        let insertButtonWidth: CGFloat
        let insertButtonHeight: CGFloat
        let isCompact: Bool
    }

struct TimelineCardView: View {
    let card: Card
    var isWrong: Bool = false
    var isCompactLayout: Bool = false
    
    private var categoryColor: Color {
        Color(hex: card.category.color) ?? .blue
    }
    
    var body: some View {
        let titleFontSize: CGFloat = isCompactLayout ? 16 : 20
        let detailFontSize: CGFloat = isCompactLayout ? 11 : 13
        let badgeFontSize: CGFloat = isCompactLayout ? 11 : 13
        let dateFontSize: CGFloat = isCompactLayout ? 20 : 26
        let cardSpacing: CGFloat = isCompactLayout ? 8 : 12
        let capsulePadding: CGFloat = isCompactLayout ? 6 : 8
        
        return VStack(alignment: .leading, spacing: cardSpacing) {
            HStack(spacing: 8) {
                Circle()
                    .fill(categoryColor.opacity(0.9))
                    .frame(width: isCompactLayout ? 8 : 10, height: isCompactLayout ? 8 : 10)
                Text(card.category.displayName)
                    .font(.system(size: badgeFontSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, capsulePadding)
                    .padding(.vertical, capsulePadding / 2)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                Spacer(minLength: 4)
                if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isCompactLayout ? 16 : 18, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            Text(card.title)
                .font(.system(size: titleFontSize, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(isCompactLayout ? 3 : 4)
                .minimumScaleFactor(0.85)
            
            if let hint = card.hint, !hint.isEmpty {
                Text(hint)
                    .font(.system(size: detailFontSize))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            } else if !card.description.isEmpty {
                Text(card.description)
                    .font(.system(size: detailFontSize))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            
            Spacer(minLength: isCompactLayout ? 2 : 6)
            
            Text(card.formattedDate)
                .font(.system(size: dateFontSize, weight: .heavy))
                .foregroundColor(isWrong ? .red : .yellow)
        }
        .padding(.vertical, isCompactLayout ? 14 : 20)
        .padding(.horizontal, isCompactLayout ? 12 : 20)
        .frame(maxWidth: .infinity, minHeight: isCompactLayout ? 170 : 220, maxHeight: isCompactLayout ? 190 : 260)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.6), Color.black.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isWrong ? Color.red : Color.white.opacity(0.35), lineWidth: isWrong ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: isCompactLayout ? 6 : 10, x: 0, y: isCompactLayout ? 5 : 8)
        .scaleEffect(isWrong ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isWrong)
    }
}


#Preview {
    GameView()
        .environmentObject(AppState())
}
