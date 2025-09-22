//
//  SoloGameService.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import SwiftUI
import Combine

final class SoloGameService: ObservableObject {
    static let shared = SoloGameService()
    
    @Published var currentCard: Card?
    @Published var nextCard: Card?
    @Published var timeline: [Card] = []
    @Published var remainingCards: [Card] = []
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var streak: Int = 0
    @Published var currentStreak: Int = 0  // Ajout pour la série actuelle
    @Published var bestStreak: Int = 0
    @Published var accuracy: Double = 100.0  // Ajout pour la précision
    @Published var gameState: SoloGameState = .menu
    @Published var difficulty: Difficulty = .normal
    
    private let deckService = DeckService.shared
    private var allCards: [Card] = []
    private var totalAttempts: Int = 0
    private var correctPlacements: Int = 0
    
    enum SoloGameState {
        case menu
        case playing
        case gameOver
        case victory
    }
    
    enum Difficulty: String, CaseIterable {
        case easy = "Facile"
        case normal = "Normal"
        case hard = "Difficile"
        
        var lives: Int {
            switch self {
            case .easy: return 5
            case .normal: return 3
            case .hard: return 1
            }
        }
        
        var cardCount: Int {
            switch self {
            case .easy: return 20
            case .normal: return 30
            case .hard: return 50
            }
        }
        
        var description: String {
            switch self {
            case .easy: return "5 vies, 20 cartes"
            case .normal: return "3 vies, 30 cartes"
            case .hard: return "1 vie, 50 cartes"
            }
        }
    }
    
    private init() {}
    
    /// Start a new solo game
    func startNewGame(difficulty: Difficulty = .normal) {
        self.difficulty = difficulty
        self.lives = difficulty.lives
        self.score = 0
        self.streak = 0
        self.currentStreak = 0
        self.bestStreak = 0
        self.accuracy = 100.0
        self.totalAttempts = 0
        self.correctPlacements = 0
        self.timeline = []
        
        // Generate deck
        allCards = deckService.generateDeck(seed: Int.random(in: 0..<10000), count: difficulty.cardCount)
        remainingCards = allCards
        
        // Place first card in timeline
        if let firstCard = remainingCards.popLast() {
            timeline.append(firstCard)
        }
        
        // Draw next card
        drawNextCard()
        
        gameState = .playing
    }
    
    /// Draw the next card to place
    private func drawNextCard() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.remainingCards.isEmpty else {
                // Victory!
                self.gameState = .victory
                self.saveHighScore()
                return
            }
            
            self.currentCard = self.remainingCards.popLast()
            
            // Preview next card for strategy
            self.nextCard = self.remainingCards.last
        }
    }
    
    /// Try to place the current card at the specified position
    func placeCard(at index: Int) -> Bool {
        guard let card = currentCard else { return false }
        
        let isCorrect = validatePlacement(card: card, at: index)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.totalAttempts += 1
            
            if isCorrect {
                // Correct placement
                self.timeline.insert(card, at: index)
                self.score += self.calculatePoints()
                self.streak += 1
                self.currentStreak += 1
                if self.currentStreak > self.bestStreak {
                    self.bestStreak = self.currentStreak
                }
                self.correctPlacements += 1
                
                AudioHapticsService.shared.playCardPlacement(isCorrect: true)
                
                // Draw next card
                self.drawNextCard()
            } else {
                // Wrong placement
                self.lives -= 1
                self.streak = 0
                self.currentStreak = 0
                
                AudioHapticsService.shared.playCardPlacement(isCorrect: false)
                
                if self.lives <= 0 {
                    self.gameState = .gameOver
                    self.saveHighScore()
                } else {
                    // Show correct position briefly, then continue
                    self.showCorrectPosition(for: card)
                }
            }
            
            // Update accuracy
            if self.totalAttempts > 0 {
                self.accuracy = Double(self.correctPlacements) / Double(self.totalAttempts) * 100.0
            }
        }
        
        return isCorrect
    }
    
    /// Validate if the card placement is correct
    private func validatePlacement(card: Card, at index: Int) -> Bool {
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
    
    /// Calculate points based on timeline size and streak
    private func calculatePoints() -> Int {
        let basePoints = 10
        let timelineBonus = timeline.count * 2
        let streakBonus = streak * 5
        let difficultyMultiplier: Int
        
        switch difficulty {
        case .easy: difficultyMultiplier = 1
        case .normal: difficultyMultiplier = 2
        case .hard: difficultyMultiplier = 3
        }
        
        return (basePoints + timelineBonus + streakBonus) * difficultyMultiplier
    }
    
    /// Show the correct position for a card
    private func showCorrectPosition(for card: Card) {
        // Find correct position
        var correctIndex = 0
        for (index, timelineCard) in timeline.enumerated() {
            if card.isBefore(timelineCard) {
                correctIndex = index
                break
            }
            correctIndex = index + 1
        }
        
        // Insert temporarily with animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.timeline.insert(card, at: correctIndex)
            
            // Continue after showing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.drawNextCard()
            }
        }
    }
    
    /// Use a hint (costs points)
    func useHint() -> Int? {
        guard let card = currentCard else { return nil }
        
        // Deduct points for hint
        score = max(0, score - 50)
        currentStreak = 0  // Reset current streak when using hint
        
        // Find correct position
        var correctIndex = 0
        for (index, timelineCard) in timeline.enumerated() {
            if card.isBefore(timelineCard) {
                correctIndex = index
                break
            }
            correctIndex = index + 1
        }
        
        return correctIndex
    }
    
    /// Skip current card (costs a life)
    func skipCard() {
        guard currentCard != nil else { return }
        
        lives -= 1
        currentStreak = 0
        totalAttempts += 1
        
        // Update accuracy
        if totalAttempts > 0 {
            accuracy = Double(correctPlacements) / Double(totalAttempts) * 100.0
        }
        
        if lives <= 0 {
            gameState = .gameOver
            saveHighScore()
        } else {
            drawNextCard()
        }
    }
    
    /// Restart the game
    func restartGame() {
        startNewGame(difficulty: difficulty)
    }
    
    /// Return to menu
    func returnToMenu() {
        gameState = .menu
        timeline = []
        currentCard = nil
        nextCard = nil
        remainingCards = []
    }
    
    /// Save high score locally
    private func saveHighScore() {
        let highScore = HighScore(
            score: score,
            difficulty: difficulty.rawValue,
            cardsPlaced: timeline.count,
            bestStreak: bestStreak,
            date: Date()
        )
        
        HighScoreManager.shared.saveHighScore(highScore)
    }
}

/// High score model
struct HighScore: Codable {
    let score: Int
    let difficulty: String
    let cardsPlaced: Int
    let bestStreak: Int
    let date: Date
}

/// Manager for high scores
final class HighScoreManager {
    static let shared = HighScoreManager()
    
    @AppStorage("highScores") private var highScoresData: Data = Data()
    
    private init() {}
    
    func saveHighScore(_ highScore: HighScore) {
        var scores = getHighScores()
        scores.append(highScore)
        scores.sort { $0.score > $1.score }
        scores = Array(scores.prefix(10)) // Keep top 10
        
        if let encoded = try? JSONEncoder().encode(scores) {
            highScoresData = encoded
        }
    }
    
    func getHighScores() -> [HighScore] {
        if let scores = try? JSONDecoder().decode([HighScore].self, from: highScoresData) {
            return scores
        }
        return []
    }
    
    func getHighScore(for difficulty: SoloGameService.Difficulty) -> Int {
        return getHighScores()
            .filter { $0.difficulty == difficulty.rawValue }
            .first?.score ?? 0
    }
}