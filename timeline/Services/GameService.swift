//
//  GameService.swift
//  timelinen 
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor final class GameService: ObservableObject {
    static let shared = GameService()
    
    private var db: Firestore {
        Firestore.firestore()
    }
    private let authService = AuthService.shared
    
    @Published var currentGame: Game?
    @Published var currentRound: Round?
    @Published var players: [Player] = []
    @Published var submissions: [Submission] = []
    @Published var timeline: [Card] = []  // Timeline partagée entre tous les joueurs
    @Published var currentCard: Card?      // Carte actuelle à placer
    @Published var playerLives: [String: Int] = [:]  // Vies par joueur
    @Published var error: Error?
    
    private var gameListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?
    private var roundListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?
    
    private var serverTimeOffset: TimeInterval = 0
    
    private init() {}
    
    deinit {
        gameListener?.remove()
        playersListener?.remove()
        roundListener?.remove()
        submissionsListener?.remove()
    }
    
    /// Calculate server time offset for timer synchronization
    func calibrateServerTime() async throws {
        let startTime = Date()
        let serverTimestamp = FieldValue.serverTimestamp()
        
        try await db.collection("time_calibration")
            .document(UUID().uuidString)
            .setData(["timestamp": serverTimestamp])
        
        let roundTrip = Date().timeIntervalSince(startTime)
        serverTimeOffset = roundTrip / 2
    }
    
    /// Get current server time
    var serverTime: Date {
        Date().addingTimeInterval(serverTimeOffset)
    }
    
    /// Generate a unique 4-digit code
    private func generateShortCode() async throws -> String {
        let maxAttempts = 10
        
        for attempt in 0..<maxAttempts {
            let code = String(format: "%04d", Int.random(in: 1000...9999))
            print("🔵 Generating short code attempt \(attempt + 1): \(code)")
            
            // Check if code already exists
            let query = db.collection("games")
                .whereField("shortCode", isEqualTo: code)
                .whereField("status", in: [GameStatus.lobby.rawValue, GameStatus.running.rawValue])
                .limit(to: 1)
            
            let snapshot = try await query.getDocuments()
            print("🔵 Code \(code) exists? \(snapshot.documents.count > 0)")
            
            if snapshot.documents.isEmpty {
                print("🔵 Using short code: \(code)")
                return code
            }
        }
        
        // Fallback to longer code if can't find unique 4-digit
        let longCode = String(format: "%06d", Int.random(in: 100000...999999))
        print("🔵 Fallback to longer code: \(longCode)")
        return longCode
    }
    
    /// Create a new game lobby
    func createGame(mode: GameMode = .privateGame) async throws -> String {
        guard let userId = authService.userId else {
            throw GameError.notAuthenticated
        }
        
        let gameRef = db.collection("games").document()
        let gameId = gameRef.documentID
        
        // Generate short code for private games
        let shortCode = mode == .privateGame ? try await generateShortCode() : nil
        
        // Only set start time for Battle Royale mode
        var gameData: [String: Any] = [
            "status": GameStatus.lobby.rawValue,
            "mode": mode.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "currentRound": 0,
            "maxPlayers": mode.maxPlayers,
            "deckSeed": Int.random(in: 0..<10000),
            "playersCount": 1,
            "aliveCount": 1,
            "hostId": userId
        ]
        
        if let shortCode = shortCode {
            gameData["shortCode"] = shortCode
            print("🟢 Creating game with short code: \(shortCode)")
        }
        
        // Battle Royale starts in 60 seconds, private games have no timer
        if mode == .battleRoyale {
            let startTime = Date().addingTimeInterval(60)
            gameData["startsAt"] = Timestamp(date: startTime)
            print("🟢 Creating Battle Royale with startsAt: \(startTime)")
        } else {
            print("🟢 Creating private game without timer")
        }
        
        let playerData: [String: Any] = [
            "displayName": generateRandomDisplayName(),
            "isHost": true,
            "isEliminated": false,
            "joinedAt": FieldValue.serverTimestamp(),
            "lastSeenAt": FieldValue.serverTimestamp(),
            "score": 0,
            "avgResponseMs": 0.0,
            "avatar": generateRandomAvatar()
        ]
        
        let batch = db.batch()
        batch.setData(gameData, forDocument: gameRef)
        batch.setData(playerData, forDocument: gameRef.collection("players").document(userId))
        
        try await batch.commit()
        print("🟢 Game created with ID: \(gameId), shortCode: \(shortCode ?? "none")")
        
        // Verify game was created
        let verifyDoc = try await db.collection("games").document(gameId).getDocument()
        if let data = verifyDoc.data() {
            print("🟢 Verification - Game exists with data: shortCode=\(data["shortCode"] ?? "nil"), status=\(data["status"] ?? "nil")")
        } else {
            print("🔴 Verification - Game document not found!")
        }
        
        await startListening(gameId: gameId)
        
        // Wait for the listener to get the game data (max 2 seconds)
        let maxWaitTime = Date().addingTimeInterval(2)
        while currentGame == nil && Date() < maxWaitTime {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if currentGame == nil {
            print("🔴 Warning: Game listener didn't receive data in time after creation")
        }
        
        return gameId
    }
    
    /// Join or create Battle Royale lobby
    func joinBattleRoyale() async throws -> String {
        guard authService.userId != nil else {
            throw GameError.notAuthenticated
        }
        
        // Look for existing Battle Royale lobbies
        let query = db.collection("games")
            .whereField("mode", isEqualTo: GameMode.battleRoyale.rawValue)
            .whereField("status", isEqualTo: GameStatus.lobby.rawValue)
            .whereField("playersCount", isLessThan: 20)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first,
           decodeGame(from: doc.data(), id: doc.documentID) != nil {
            // Join existing Battle Royale
            print("🟣 Joining existing Battle Royale: \(doc.documentID)")
            try await joinGame(gameId: doc.documentID)
            return doc.documentID
        } else {
            // Create new Battle Royale lobby
            print("🟣 Creating new Battle Royale lobby")
            return try await createGame(mode: .battleRoyale)
        }
    }
    
    /// Join game by code (tries short code first, then full ID)
    func joinGameByCode(_ code: String) async throws {
        // Validate input
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw GameError.gameNotFound
        }
        
        print("🟣 Trying to join with code: '\(trimmedCode)' (length: \(trimmedCode.count))")
        
        // First try as short code (4-6 digits)
        if trimmedCode.count >= 4 && trimmedCode.count <= 6 {
            let isNumeric = trimmedCode.allSatisfy({ $0.isNumber })
            print("🟣 Code is numeric: \(isNumeric)")
            
            if isNumeric {
                // Search for games with this short code (we'll check status after)
                let query = db.collection("games")
                    .whereField("shortCode", isEqualTo: trimmedCode)
                    .limit(to: 10)
                
                print("🟣 Searching for games with shortCode == '\(trimmedCode)'")
                let snapshot = try await query.getDocuments()
                print("🟣 Found \(snapshot.documents.count) games with this code")
                
                // Log all found games
                for (index, doc) in snapshot.documents.enumerated() {
                    let data = doc.data()
                    print("🟣 Game \(index + 1): id=\(doc.documentID), status=\(data["status"] ?? "nil"), shortCode=\(data["shortCode"] ?? "nil")")
                }
                
                // Find the first game that is in lobby or running state
                for doc in snapshot.documents {
                    let data = doc.data()
                    if let statusString = data["status"] as? String,
                       let status = GameStatus(rawValue: statusString),
                       (status == .lobby || status == .running) {
                        print("🟣 Found active game with short code: \(doc.documentID), status: \(status)")
                        try await joinGame(gameId: doc.documentID)
                        return
                    }
                }
                
                print("🟣 No active game found with short code: \(trimmedCode)")
                throw GameError.gameNotFound
            }
        }
        
        // Try as full game ID only if it looks like a Firebase ID
        if trimmedCode.count > 10 {
            try await joinGame(gameId: trimmedCode)
        } else {
            throw GameError.gameNotFound
        }
    }
    
    /// Join an existing game
    func joinGame(gameId: String) async throws {
        print("🟣 Joining game: \(gameId)")
        
        // Validate gameId
        guard !gameId.isEmpty else {
            print("🟣 Error: Empty game ID")
            throw GameError.gameNotFound
        }
        
        guard let userId = authService.userId else {
            throw GameError.notAuthenticated
        }
        
        let gameRef = db.collection("games").document(gameId)
        let gameDoc = try await gameRef.getDocument()
        
        guard let data = gameDoc.data(),
              let game = decodeGame(from: data, id: gameId) else {
            throw GameError.gameNotFound
        }
        
        print("🟣 Game found, status: \(game.status), players: \(game.playersCount)")
        
        // Allow joining games in lobby or running state
        guard game.status == .lobby || game.status == .running else {
            throw GameError.gameAlreadyStarted
        }
        
        guard game.playersCount < game.maxPlayers else {
            throw GameError.gameFull
        }
        
        let playerData: [String: Any] = [
            "displayName": generateRandomDisplayName(),
            "isHost": false,
            "isEliminated": false,
            "joinedAt": FieldValue.serverTimestamp(),
            "lastSeenAt": FieldValue.serverTimestamp(),
            "score": 0,
            "avgResponseMs": 0.0,
            "avatar": generateRandomAvatar()
        ]
        
        let batch = db.batch()
        batch.setData(playerData, forDocument: gameRef.collection("players").document(userId))
        batch.updateData(["playersCount": FieldValue.increment(Int64(1))], forDocument: gameRef)
        
        // Don't update startsAt for private games
        // Battle Royale games already have their timer set
        
        try await batch.commit()
        
        await startListening(gameId: gameId)
        
        // Wait for the listener to get the game data (max 2 seconds)
        let maxWaitTime = Date().addingTimeInterval(2)
        while currentGame == nil && Date() < maxWaitTime {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if currentGame == nil {
            print("🔴 Warning: Game listener didn't receive data in time")
        }
    }
    
    /// Start listening to game updates
    private func startListening(gameId: String) async {
        stopListening()
        
        let gameRef = db.collection("games").document(gameId)
        
        gameListener = gameRef.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                if let error = error {
                    print("🔴 GameService listener error: \(error)")
                    self.error = error
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("🔴 GameService listener: No data in snapshot")
                    return
                }
                
                print("🟢 GameService listener: Game data received")
                print("🟢 - shortCode: \(data["shortCode"] ?? "nil")")
                print("🟢 - status: \(data["status"] ?? "nil")")
                print("🟢 - mode: \(data["mode"] ?? "nil")")
                
                self.currentGame = self.decodeGame(from: data, id: snapshot?.documentID)
                
                if let game = self.currentGame {
                    print("🟢 GameService: Current game set - ID: \(game.id ?? "nil"), shortCode: \(game.shortCode ?? "nil")")
                    print("🔄 Game status: \(game.status.rawValue), currentRound: \(game.currentRound))")
                    if game.status == .running {
                        let currentRound = game.currentRound
                        if currentRound > 0 {
                            print("🔄 Starting to listen to round \(currentRound)")
                            self.listenToRound(gameId: gameId, roundIndex: currentRound)
                        } else {
                            print("⚠️ Game is running but no current round set")
                        }
                    } else if game.status == .lobby {
                        print("🎮 Game still in lobby, waiting for start...")
                    }
                }
            }
        }

        playersListener = gameRef.collection("players")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error = error {
                        print("❌ Players listener error: \(error.localizedDescription)")
                        self.error = error
                        return
                    }
                    
                    print("👥 Players update: \(snapshot?.documents.count ?? 0) players")
                    let decodedPlayers = snapshot?.documents.compactMap { doc -> Player? in
                        let player = self.decodePlayer(from: doc.data(), id: doc.documentID)
                        if let lives = doc.data()["lives"] as? Int {
                            self.playerLives[doc.documentID] = lives
                            if lives <= 0 && player?.isEliminated == false {
                                self.db.collection("games").document(gameId)
                                    .collection("players").document(doc.documentID)
                                    .updateData(["isEliminated": true])
                            }
                        }
                        return player
                    } ?? []
                    self.players = decodedPlayers
                }
            }
        
        submissionsListener = gameRef.collection("submissions")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Submissions listener error: \(error.localizedDescription)")
                    self?.error = error
                    return
                }
                
                print("📄 Submissions update: \(snapshot?.documents.count ?? 0) submissions")
                self?.submissions = snapshot?.documents.compactMap { doc in
                    self?.decodeSubmission(from: doc.data())
                } ?? []
                
                if let roundIndex = self?.currentRound?.roundIndex {
                    Task {
                        await self?.checkRoundCompletion(gameId: gameId, roundIndex: roundIndex)
                    }
                }
            }
    }
    
    /// Listen to current round
    private func listenToRound(gameId: String, roundIndex: Int) {
        print("🔄 listenToRound called for round \(roundIndex)")
        roundListener?.remove()
        
        guard currentGame?.deckSeed != nil else {
            print("❌ No deck seed available")
            return
        }
        
        roundListener = db.collection("games").document(gameId)
            .collection("rounds").document("\(roundIndex)")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    
                    if let error = error {
                        print("❌ Round listener error: \(error.localizedDescription)")
                        self.error = error
                        return
                    }
                    
                    guard let data = snapshot?.data() else {
                        print("⚠️ No data in round snapshot")
                        return
                    }
                    
                    print("✅ Round \(roundIndex) data received:")
                    print("  - cardId: \(data["cardId"] ?? "nil")")
                    print("  - cardIndex: \(data["cardIndex"] ?? "nil")")
                    print("  - resolved: \(data["resolved"] ?? "nil")")
                    print("  - timelineBefore: \(data["timelineBefore"] ?? "nil")")
                    
                    self.currentRound = self.decodeRound(from: data, index: roundIndex)
                    
                    guard let deckSeed = self.currentGame?.deckSeed else {
                        print("❌ No deck seed available for loading cards")
                        return
                    }
                    
                    let cards = DeckService.shared.generateDeck(seed: deckSeed, count: 30)
                    let cardIndex = data["cardIndex"] as? Int ?? 0
                    
                    self.currentCard = self.selectCurrentCard(from: data, cards: cards, fallbackIndex: cardIndex)
                    if let currentCard = self.currentCard {
                        print("🃏 Current card loaded: \(currentCard.title) (\(currentCard.year))")
                    } else {
                        print("❌ Could not load current card")
                    }
                    
                    let timelineCards = self.buildTimeline(from: data, cards: cards, fallbackIndex: cardIndex)
                    self.timeline = timelineCards
                    self.logTimeline(timelineCards)
                    
                    if let resolved = data["resolved"] as? Bool,
                       resolved,
                       let correctPosition = data["correctPosition"] as? Int,
                       let card = self.currentCard {
                        print("🎯 Round resolved! Correct position: \(correctPosition)")
                        self.insertResolvedCard(card, at: correctPosition)
                    }
                }
            }
    }

    private func selectCurrentCard(from data: [String: Any], cards: [Card], fallbackIndex: Int) -> Card? {
        if let cardId = data["cardId"] as? String,
           let card = cards.first(where: { $0.id == cardId }) {
            return card
        }
        if fallbackIndex >= 0 && fallbackIndex < cards.count {
            return cards[fallbackIndex]
        }
        return nil
    }
    
    private func buildTimeline(from data: [String: Any], cards: [Card], fallbackIndex: Int) -> [Card] {
        if let timelineIds = data["timelineBefore"] as? [String], !timelineIds.isEmpty {
            let uniqueIds = orderedUniqueIds(timelineIds)
            let mappedCards = mapTimeline(ids: uniqueIds, using: cards)
            if mappedCards.count == uniqueIds.count {
                return mappedCards
            }
            print("⚠️ Timeline ids missing, using reconstructed timeline order")
        }
        return fallbackTimeline(for: cards, upTo: fallbackIndex)
    }
    
    private func orderedUniqueIds(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for id in ids {
            if seen.insert(id).inserted {
                unique.append(id)
            }
        }
        return unique
    }
    
    private func mapTimeline(ids: [String], using cards: [Card]) -> [Card] {
        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return cards.first { $0.id == id }
        }
    }
    
    private func fallbackTimeline(for cards: [Card], upTo index: Int) -> [Card] {
        guard !cards.isEmpty else { return [] }
        let safeEnd = min(max(index, 1), cards.count)
        let prefix = Array(cards.prefix(safeEnd))
        return sanitizeTimeline(prefix).sorted { $0.isBefore($1) }
    }
    
    private func sanitizeTimeline(_ cards: [Card]) -> [Card] {
        var seen = Set<String>()
        return cards.filter { seen.insert($0.id).inserted }
    }
    
    private func timelineIds(from cards: [Card]) -> [String] {
        var seen = Set<String>()
        return cards.reduce(into: [String]()) { result, card in
            if seen.insert(card.id).inserted {
                result.append(card.id)
            }
        }
    }
    
    private func insertResolvedCard(_ card: Card, at position: Int) {
        timeline = sanitizeTimeline(timeline.filter { $0.id != card.id })
        let clampedIndex = max(0, min(position, timeline.count))
        timeline.insert(card, at: clampedIndex)
        timeline = sanitizeTimeline(timeline)
        logTimeline(timeline)
    }
    
    private func logTimeline(_ cards: [Card]) {
        print("📊 Timeline updated with \(cards.count) card(s):")
        for card in cards {
            print("  - \(card.title) (\(card.year))")
        }
    }
    
    /// Submit card placement
    func submitPlacement(positionIndex: Int) async throws {
        guard let userId = authService.userId,
              let game = currentGame,
              let gameId = game.id,
              let round = currentRound,
              let currentCard = currentCard else {
            throw GameError.invalidState
        }
        
        guard round.isActive else {
            throw GameError.roundExpired
        }
        
        // Validate placement locally
        let isCorrect = validatePlacement(card: currentCard, at: positionIndex)
        
        // Create submission
        let submission = Submission(
            playerId: userId,
            roundIndex: round.roundIndex,
            positionIndex: positionIndex,
            submittedAt: Date(),
            isCorrect: isCorrect,
            latencyMs: Date().timeIntervalSince(round.roundStartsAt) * 1000
        )
        
        let batch = db.batch()
        
        let submissionData: [String: Any] = [
            "playerId": submission.playerId,
            "roundIndex": submission.roundIndex,
            "positionIndex": submission.positionIndex,
            "submittedAt": Timestamp(date: submission.submittedAt),
            "isCorrect": submission.isCorrect,
            "latencyMs": submission.latencyMs
        ]
        
        // Add submission
        batch.setData(submissionData, forDocument: db.collection("games").document(gameId)
            .collection("submissions").document(submission.id))
        
        // Update player stats
        if !isCorrect {
            batch.updateData([
                "lives": FieldValue.increment(Int64(-1)),
                "errors": FieldValue.increment(Int64(1))
            ], forDocument: db.collection("games").document(gameId)
                .collection("players").document(userId))
        }
        
        try await batch.commit()
        
        // Check if all alive players have submitted
        await checkRoundCompletion(gameId: gameId, roundIndex: round.roundIndex)
    }
    
    /// Stop all listeners
    func stopListening() {
        gameListener?.remove()
        playersListener?.remove()
        roundListener?.remove()
        submissionsListener?.remove()
        
        gameListener = nil
        playersListener = nil
        roundListener = nil
        submissionsListener = nil
    }
    
    /// Start the game (host only for private games)
    func startGame() async {
        print("🎮 startGame called")
        
        guard let gameId = currentGame?.id else {
            print("❌ No current game ID")
            return
        }
        
        guard let userId = authService.userId else {
            print("❌ No user ID")
            return
        }
        
        guard let deckSeed = currentGame?.deckSeed else {
            print("❌ No deck seed")
            return
        }
        
        print("📝 Game info: id=\(gameId), userId=\(userId), deckSeed=\(deckSeed)")
        print("👥 Current players: \(players.count)")
        print("🎯 Game mode: \(currentGame?.mode.rawValue ?? "unknown")")
        print("🏠 Host ID: \(currentGame?.hostId ?? "none")")
        
        // Only host can start private games
        if currentGame?.mode == .privateGame && currentGame?.hostId != userId {
            print("⚠️ Only host can start private game")
            return
        }
        
        do {
            print("🎲 Generating deck with seed \(deckSeed)...")
            // Generate the deck of cards
            let cards = DeckService.shared.generateDeck(seed: deckSeed, count: 30)
            print("✅ Generated \(cards.count) cards")
            
            // Initialize game with first card in timeline and draw next card
            let firstCard = cards[0]
            let secondCard = cards[1]
            print("🃏 First card: \(firstCard.title) (\(firstCard.year))")
            print("🃏 Second card: \(secondCard.title) (\(secondCard.year))")
            
            print("📦 Creating batch update...")
            let batch = db.batch()
            
            // Update game status to running
            let gameUpdate = [
                "status": GameStatus.running.rawValue,
                "currentRound": 1,
                "totalCards": cards.count
            ] as [String: Any]
            print("🔄 Updating game status to running...")
            batch.updateData(gameUpdate, forDocument: db.collection("games").document(gameId))
            
            // Create first round with second card (first card is already in timeline)
            let roundEndTime = Date().addingTimeInterval(30)
            let roundData: [String: Any] = [
                "cardId": secondCard.id,
                "cardIndex": 1,  // Index in the deck
                "roundIndex": 1,
                "roundStartsAt": FieldValue.serverTimestamp(),
                "roundEndsAt": Timestamp(date: roundEndTime),  // 30 seconds
                "resolved": false,
                "timelineBefore": [firstCard.id]  // First card is already in timeline
            ]
            print("⏰ Creating round 1, ends at \(roundEndTime)")
            batch.setData(roundData, forDocument: db.collection("games").document(gameId)
                .collection("rounds").document("1"))
            
            // Initialize player lives (3 lives each)
            print("❤️ Initializing lives for \(players.count) players...")
            for player in players {
                if let playerId = player.id {
                    print("  - Setting lives for player \(player.displayName)")
                    batch.updateData([
                        "lives": 3,
                        "errors": 0
                    ], forDocument: db.collection("games").document(gameId)
                        .collection("players").document(playerId))
                }
            }
            
            print("🚀 Committing batch update...")
            try await batch.commit()
            print("✅ Game started successfully!")
            
            // Load the timeline with first card locally
            self.timeline = sanitizeTimeline([firstCard])
            self.currentCard = secondCard
            print("📊 Timeline initialized with \(timeline.count) card(s)")
            print("🎯 Current card to place: \(secondCard.title)")
            
        } catch {
            print("❌ Error starting game: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Leave current game
    func leaveGame() {
        stopListening()
        currentGame = nil
        currentRound = nil
        players = []
        submissions = []
        timeline = []
        currentCard = nil
        playerLives = [:]
    }
    
    /// Generate random display name
    private func generateRandomDisplayName() -> String {
        let adjectives = ["Swift", "Rapide", "Brillant", "Astucieux", "Sage", "Courageux", "Vaillant", "Noble"]
        let nouns = ["Historien", "Explorateur", "Savant", "Pionnier", "Chercheur", "Aventurier", "Érudit", "Découvreur"]
        let number = Int.random(in: 1...99)
        
        return "\(adjectives.randomElement()!)\(nouns.randomElement()!)\(number)"
    }
    
    /// Generate random avatar
    private func generateRandomAvatar() -> String {
        let avatars = ["🎯", "🎲", "🎨", "🎭", "🎪", "🎬", "🎮", "🎯", "🏆", "⭐", "💎", "🔮", "🎓", "🧩", "🎯"]
        return avatars.randomElement()!
    }
    
    /// Validate card placement
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
    
    /// Check if round is complete and move to next
    private func checkRoundCompletion(gameId: String, roundIndex: Int) async {
        guard let currentGame = currentGame else {
            print("⚠️ checkRoundCompletion skipped: no current game")
            return
        }
        
        // Ensure only the host orchestrates round transitions to avoid duplicate writes
        guard authService.userId == currentGame.hostId else {
            return
        }
        
        // Get all submissions for current round
        let roundSubmissions = submissions.filter { $0.roundIndex == roundIndex }
        
        // Get alive players
        let alivePlayers = players.filter { player in
            if let playerId = player.id, let lives = playerLives[playerId] {
                return lives > 0 && !player.isEliminated
            }
            return false
        }
        
        // Check if all alive players have submitted
        let submittedPlayerIds = Set(roundSubmissions.map { $0.playerId })
        let alivePlayerIds = Set(alivePlayers.compactMap { $0.id })
        
        print("📝 Round \(roundIndex) submissions: \(submittedPlayerIds.count)/\(alivePlayerIds.count)")
        
        if submittedPlayerIds == alivePlayerIds || roundSubmissions.count >= alivePlayers.count {
            // All alive players have submitted, move to next round
            await processRoundEnd(gameId: gameId, roundIndex: roundIndex)
        }
    }
    
    /// Process end of round
    private func processRoundEnd(gameId: String, roundIndex: Int) async {
        guard let currentCard = currentCard,
              let deckSeed = currentGame?.deckSeed else { return }
        
        do {
            // Find correct position for the card
            let correctPosition = findCorrectPosition(for: currentCard)
            
            // Update timeline locally with sanitized ordering
            timeline = sanitizeTimeline(timeline.filter { $0.id != currentCard.id })
            let clampedPosition = max(0, min(correctPosition, timeline.count))
            timeline.insert(currentCard, at: clampedPosition)
            timeline = sanitizeTimeline(timeline)
            let timelineIdsSnapshot = timelineIds(from: timeline)
            
            // Get next card from deck
            let cards = DeckService.shared.generateDeck(seed: deckSeed, count: 30)
            let nextRoundIndex = roundIndex + 1
            
            if nextRoundIndex < cards.count {
                let nextCard = cards[nextRoundIndex]
                
                // Create next round
                let roundData: [String: Any] = [
                    "cardId": nextCard.id,
                    "cardIndex": nextRoundIndex,
                    "roundStartsAt": FieldValue.serverTimestamp(),
                    "roundEndsAt": Timestamp(date: Date().addingTimeInterval(30)),
                    "resolved": false,
                    "timelineBefore": timelineIdsSnapshot,
                    "correctPosition": correctPosition
                ]
                
                let batch = db.batch()
                
                // Mark current round as resolved
                batch.updateData([
                    "resolved": true,
                    "correctPosition": correctPosition
                ], forDocument: db.collection("games").document(gameId)
                    .collection("rounds").document("\(roundIndex)"))
                
                // Create next round
                batch.setData(roundData, forDocument: db.collection("games").document(gameId)
                    .collection("rounds").document("\(nextRoundIndex)"))
                
                // Update game current round
                batch.updateData([
                    "currentRound": nextRoundIndex
                ], forDocument: db.collection("games").document(gameId))
                
                try await batch.commit()
                
                // Update local card
                self.currentCard = nextCard
                
            } else {
                // Game is complete
                try await db.collection("games").document(gameId).updateData([
                    "status": GameStatus.finished.rawValue
                ])
            }
            
        } catch {
            self.error = error
        }
    }
    
    /// Find correct position for a card in timeline
    private func findCorrectPosition(for card: Card) -> Int {
        for (index, timelineCard) in timeline.enumerated() {
            if card.isBefore(timelineCard) {
                return index
            }
        }
        return timeline.count
    }
    
    /// Decode Game from Firestore data
    private func decodeGame(from data: [String: Any], id: String?) -> Game? {
        guard let status = data["status"] as? String,
              let gameStatus = GameStatus(rawValue: status),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let currentRound = data["currentRound"] as? Int,
              let maxPlayers = data["maxPlayers"] as? Int,
              let deckSeed = data["deckSeed"] as? Int,
              let playersCount = data["playersCount"] as? Int,
              let aliveCount = data["aliveCount"] as? Int,
              let hostId = data["hostId"] as? String else {
            return nil
        }
        
        // Default to private game if mode is not specified (for backward compatibility)
        let modeString = data["mode"] as? String ?? GameMode.privateGame.rawValue
        let gameMode = GameMode(rawValue: modeString) ?? .privateGame
        
        let shortCode = data["shortCode"] as? String
        let startsAt = (data["startsAt"] as? Timestamp)?.dateValue()
        
        return Game(
            id: id,
            shortCode: shortCode,
            status: gameStatus,
            mode: gameMode,
            createdAt: createdAt,
            startsAt: startsAt,
            currentRound: currentRound,
            maxPlayers: maxPlayers,
            deckSeed: deckSeed,
            playersCount: playersCount,
            aliveCount: aliveCount,
            hostId: hostId
        )
    }
    
    /// Decode Player from Firestore data
    private func decodePlayer(from data: [String: Any], id: String?) -> Player? {
        guard let displayName = data["displayName"] as? String,
              let isHost = data["isHost"] as? Bool,
              let isEliminated = data["isEliminated"] as? Bool,
              let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue(),
              let lastSeenAt = (data["lastSeenAt"] as? Timestamp)?.dateValue(),
              let score = data["score"] as? Int,
              let avgResponseMs = data["avgResponseMs"] as? Double else {
            return nil
        }
        
        let avatar = data["avatar"] as? String
        
        return Player(
            id: id,
            displayName: displayName,
            isHost: isHost,
            isEliminated: isEliminated,
            joinedAt: joinedAt,
            lastSeenAt: lastSeenAt,
            score: score,
            avgResponseMs: avgResponseMs,
            avatar: avatar
        )
    }
    
    /// Decode Round from Firestore data
    private func decodeRound(from data: [String: Any], index: Int) -> Round? {
        guard let cardId = data["cardId"] as? String,
              let roundStartsAt = (data["roundStartsAt"] as? Timestamp)?.dateValue(),
              let roundEndsAt = (data["roundEndsAt"] as? Timestamp)?.dateValue(),
              let resolved = data["resolved"] as? Bool else {
            return nil
        }
        
        let timelineBefore = data["timelineBefore"] as? [String] ?? []
        
        return Round(
            roundIndex: index,
            cardId: cardId,
            roundStartsAt: roundStartsAt,
            roundEndsAt: roundEndsAt,
            resolved: resolved,
            timelineBefore: timelineBefore
        )
    }
    
    /// Decode Submission from Firestore data
    private func decodeSubmission(from data: [String: Any]) -> Submission? {
        guard let playerId = data["playerId"] as? String,
              let roundIndex = data["roundIndex"] as? Int,
              let positionIndex = data["positionIndex"] as? Int,
              let isCorrect = data["isCorrect"] as? Bool else {
            return nil
        }
        
        let submittedAt: Date
        if let timestamp = data["submittedAt"] as? Timestamp {
            submittedAt = timestamp.dateValue()
        } else if let seconds = data["submittedAt"] as? Double {
            submittedAt = Date(timeIntervalSince1970: seconds)
        } else if let stringValue = data["submittedAt"] as? String,
                  let parsedDate = ISO8601DateFormatter().date(from: stringValue) {
            submittedAt = parsedDate
        } else {
            return nil
        }
        
        let latencyMs: Double
        if let latency = data["latencyMs"] as? Double {
            latencyMs = latency
        } else if let latency = data["latencyMs"] as? NSNumber {
            latencyMs = latency.doubleValue
        } else {
            latencyMs = 0
        }
        
        return Submission(
            playerId: playerId,
            roundIndex: roundIndex,
            positionIndex: positionIndex,
            submittedAt: submittedAt,
            isCorrect: isCorrect,
            latencyMs: latencyMs
        )
    }
}

enum GameError: LocalizedError {
    case notAuthenticated
    case gameNotFound
    case gameAlreadyStarted
    case gameFull
    case invalidState
    case roundExpired
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Vous devez être connecté pour jouer"
        case .gameNotFound:
            return "Code invalide ou partie introuvable"
        case .gameAlreadyStarted:
            return "La partie a déjà commencé"
        case .gameFull:
            return "La partie est complète"
        case .invalidState:
            return "État de jeu invalide"
        case .roundExpired:
            return "Le temps est écoulé"
        }
    }
}

extension Encodable {
    func asDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
