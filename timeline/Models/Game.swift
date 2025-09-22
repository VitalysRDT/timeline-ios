//
//  Game.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import FirebaseFirestore

enum GameStatus: String, Codable {
    case lobby = "lobby"
    case running = "running"
    case finished = "finished"
}

enum GameMode: String, Codable {
    case privateGame = "private"
    case battleRoyale = "battle_royale"
    
    var displayName: String {
        switch self {
        case .privateGame: return "Partie privée"
        case .battleRoyale: return "Battle Royale"
        }
    }
    
    var description: String {
        switch self {
        case .privateGame: return "Créez une partie privée avec vos amis"
        case .battleRoyale: return "Affrontez des joueurs du monde entier"
        }
    }
    
    var maxPlayers: Int {
        switch self {
        case .privateGame: return 8
        case .battleRoyale: return 20
        }
    }
}

struct Game: Codable, Identifiable {
    var id: String?
    let shortCode: String?
    let status: GameStatus
    let mode: GameMode
    let createdAt: Date
    let startsAt: Date?
    let currentRound: Int
    let maxPlayers: Int
    let deckSeed: Int
    let playersCount: Int
    let aliveCount: Int
    let hostId: String
    
    init(id: String? = nil,
         shortCode: String? = nil,
         status: GameStatus,
         mode: GameMode = .privateGame,
         createdAt: Date,
         startsAt: Date?,
         currentRound: Int,
         maxPlayers: Int,
         deckSeed: Int,
         playersCount: Int,
         aliveCount: Int,
         hostId: String) {
        self.id = id
        self.shortCode = shortCode
        self.status = status
        self.mode = mode
        self.createdAt = createdAt
        self.startsAt = startsAt
        self.currentRound = currentRound
        self.maxPlayers = maxPlayers
        self.deckSeed = deckSeed
        self.playersCount = playersCount
        self.aliveCount = aliveCount
        self.hostId = hostId
    }
    
    var timeRemaining: TimeInterval {
        guard let startsAt = startsAt else { return 0 }
        return max(0, startsAt.timeIntervalSinceNow)
    }
    
    var isStarted: Bool {
        status == .running || status == .finished
    }
}

struct Player: Codable, Identifiable {
    var id: String?
    let displayName: String
    let isHost: Bool
    let isEliminated: Bool
    let joinedAt: Date
    let lastSeenAt: Date
    let score: Int
    let avgResponseMs: Double
    let avatar: String?
    
    init(id: String? = nil,
         displayName: String,
         isHost: Bool = false,
         isEliminated: Bool = false,
         joinedAt: Date = Date(),
         lastSeenAt: Date = Date(),
         score: Int = 0,
         avgResponseMs: Double = 0,
         avatar: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.isHost = isHost
        self.isEliminated = isEliminated
        self.joinedAt = joinedAt
        self.lastSeenAt = lastSeenAt
        self.score = score
        self.avgResponseMs = avgResponseMs
        self.avatar = avatar
    }
}

struct Round: Codable, Identifiable, Equatable {
    var id: String { "\(roundIndex)" }
    let roundIndex: Int
    let cardId: String
    let roundStartsAt: Date
    let roundEndsAt: Date
    let resolved: Bool
    let timelineBefore: [String]
    
    var timeRemaining: TimeInterval {
        max(0, roundEndsAt.timeIntervalSinceNow)
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= roundStartsAt && now <= roundEndsAt && !resolved
    }
}

struct Submission: Codable {
    let playerId: String
    let roundIndex: Int
    let positionIndex: Int
    let submittedAt: Date
    let isCorrect: Bool
    let latencyMs: Double
    
    var id: String { "\(roundIndex)_\(playerId)" }
}