//
//  CardTests.swift
//  timelineTests
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import XCTest
@testable import timeline

final class CardTests: XCTestCase {
    
    func testCardComparison() {
        let card1 = Card(title: "Event 1", description: "", year: 1500, category: .history)
        let card2 = Card(title: "Event 2", description: "", year: 1600, category: .history)
        let card3 = Card(title: "Event 3", description: "", year: 1600, month: 5, category: .history)
        let card4 = Card(title: "Event 4", description: "", year: 1600, month: 5, day: 10, category: .history)
        
        XCTAssertTrue(card1.isBefore(card2))
        XCTAssertFalse(card2.isBefore(card1))
        XCTAssertTrue(card2.isBefore(card3))
        XCTAssertTrue(card3.isBefore(card4))
    }
    
    func testCardBetween() {
        let card1 = Card(title: "Event 1", description: "", year: 1400, category: .history)
        let card2 = Card(title: "Event 2", description: "", year: 1500, category: .history)
        let card3 = Card(title: "Event 3", description: "", year: 1600, category: .history)
        
        XCTAssertTrue(card2.isBetween(card1, card3))
        XCTAssertFalse(card1.isBetween(card2, card3))
        XCTAssertFalse(card3.isBetween(card1, card2))
    }
    
    func testCardWithSameDate() {
        let card1 = Card(title: "Event 1", description: "", year: 1500, month: 6, day: 15, category: .history)
        let card2 = Card(title: "Event 2", description: "", year: 1500, month: 6, day: 15, category: .history)
        
        XCTAssertFalse(card1.isBefore(card2))
        XCTAssertFalse(card2.isBefore(card1))
        XCTAssertFalse(card1.isAfter(card2))
        XCTAssertFalse(card2.isAfter(card1))
    }
    
    func testNegativeYears() {
        let card1 = Card(title: "Ancient Event", description: "", year: -500, category: .history)
        let card2 = Card(title: "Less Ancient", description: "", year: -100, category: .history)
        let card3 = Card(title: "Modern", description: "", year: 100, category: .history)
        
        XCTAssertTrue(card1.isBefore(card2))
        XCTAssertTrue(card2.isBefore(card3))
        XCTAssertTrue(card1.isBefore(card3))
    }
    
    func testFormattedDate() {
        let card1 = Card(title: "Event", description: "", year: 1500, category: .history)
        XCTAssertEqual(card1.formattedDate, "1500")
        
        let card2 = Card(title: "Event", description: "", year: 1500, month: 6, category: .history)
        XCTAssertEqual(card2.formattedDate, "6/1500")
        
        let card3 = Card(title: "Event", description: "", year: 1500, month: 6, day: 15, category: .history)
        XCTAssertEqual(card3.formattedDate, "15/6/1500")
    }
}

final class DeckServiceTests: XCTestCase {
    
    func testDeterministicShuffle() {
        let deck = DeckService.shared
        
        let deck1 = deck.generateDeck(seed: 42, count: 10)
        let deck2 = deck.generateDeck(seed: 42, count: 10)
        let deck3 = deck.generateDeck(seed: 43, count: 10)
        
        XCTAssertEqual(deck1.map { $0.id }, deck2.map { $0.id })
        XCTAssertNotEqual(deck1.map { $0.id }, deck3.map { $0.id })
    }
    
    func testBalancedCategories() {
        let deck = DeckService.shared
        let generatedDeck = deck.generateDeck(seed: 42, count: 50)
        
        var categoryCounts: [CardCategory: Int] = [:]
        for card in generatedDeck {
            categoryCounts[card.category, default: 0] += 1
        }
        
        let counts = Array(categoryCounts.values)
        let maxCount = counts.max() ?? 0
        let minCount = counts.min() ?? 0
        
        XCTAssertLessThanOrEqual(maxCount - minCount, 3, "Categories should be balanced")
    }
}

final class GameLogicTests: XCTestCase {
    
    func testTimelineValidation() {
        let timeline = [
            Card(title: "Event 1", description: "", year: 1400, category: .history),
            Card(title: "Event 2", description: "", year: 1500, category: .history),
            Card(title: "Event 3", description: "", year: 1600, category: .history)
        ]
        
        let newCard1 = Card(title: "New 1", description: "", year: 1350, category: .history)
        let newCard2 = Card(title: "New 2", description: "", year: 1450, category: .history)
        let newCard3 = Card(title: "New 3", description: "", year: 1650, category: .history)
        
        // Test placement at beginning
        XCTAssertTrue(newCard1.isBefore(timeline[0]))
        
        // Test placement in middle
        XCTAssertTrue(newCard2.isBetween(timeline[0], timeline[1]))
        
        // Test placement at end
        XCTAssertTrue(newCard3.isAfter(timeline[2]))
    }
    
    func testEliminationLogic() {
        let player = Player(
            displayName: "Test Player",
            isEliminated: false,
            score: 5
        )
        
        XCTAssertFalse(player.isEliminated)
        
        let eliminatedPlayer = Player(
            displayName: "Eliminated Player",
            isEliminated: true,
            score: 3
        )
        
        XCTAssertTrue(eliminatedPlayer.isEliminated)
    }
}