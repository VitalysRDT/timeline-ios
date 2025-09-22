//
//  Card.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import SwiftData

enum CardCategory: String, Codable, CaseIterable {
    case technology = "TECH"
    case science = "SCIENCE"
    case history = "HISTORY"
    case culture = "CULTURE"
    case sports = "SPORTS"
    case politics = "POLITICS"
    case art = "ART"
    case discovery = "DISCOVERY"
    
    var color: String {
        switch self {
        case .technology: return "#007AFF"
        case .science: return "#34C759"
        case .history: return "#FF9500"
        case .culture: return "#AF52DE"
        case .sports: return "#FF3B30"
        case .politics: return "#5856D6"
        case .art: return "#FF2D55"
        case .discovery: return "#00C7BE"
        }
    }
    
    var displayName: String {
        switch self {
        case .technology: return "Technologie"
        case .science: return "Science"
        case .history: return "Histoire"
        case .culture: return "Culture"
        case .sports: return "Sport"
        case .politics: return "Politique"
        case .art: return "Art"
        case .discovery: return "Découverte"
        }
    }
}

struct Card: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let year: Int
    let month: Int?
    let day: Int?
    let category: CardCategory
    let imageURL: String?
    let hint: String?
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         year: Int,
         month: Int? = nil,
         day: Int? = nil,
         category: CardCategory,
         imageURL: String? = nil,
         hint: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.year = year
        self.month = month
        self.day = day
        self.category = category
        self.imageURL = imageURL
        self.hint = hint
    }
    
    var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }
    
    var formattedDate: String {
        if let day = day, let month = month {
            return "\(day)/\(month)/\(year)"
        } else if let month = month {
            return "\(month)/\(year)"
        } else {
            return "\(year)"
        }
    }
    
    /// Compare two cards chronologically
    func isBefore(_ other: Card) -> Bool {
        if year != other.year {
            return year < other.year
        }
        
        let selfMonth = month ?? 0
        let otherMonth = other.month ?? 0
        if selfMonth != otherMonth {
            return selfMonth < otherMonth
        }
        
        let selfDay = day ?? 0
        let otherDay = other.day ?? 0
        return selfDay < otherDay
    }
    
    func isAfter(_ other: Card) -> Bool {
        return other.isBefore(self)
    }
    
    func isBetween(_ before: Card, _ after: Card) -> Bool {
        return before.isBefore(self) && self.isBefore(after)
    }
}

@Model
final class LocalCard {
    var id: String
    var title: String
    var cardDescription: String
    var year: Int
    var month: Int?
    var day: Int?
    var category: String
    var imageURL: String?
    var hint: String?
    var lastPlayed: Date?
    var correctCount: Int
    var incorrectCount: Int
    
    init(from card: Card) {
        self.id = card.id
        self.title = card.title
        self.cardDescription = card.description
        self.year = card.year
        self.month = card.month
        self.day = card.day
        self.category = card.category.rawValue
        self.imageURL = card.imageURL
        self.hint = card.hint
        self.lastPlayed = nil
        self.correctCount = 0
        self.incorrectCount = 0
    }
    
    func toCard() -> Card {
        Card(
            id: id,
            title: title,
            description: cardDescription,
            year: year,
            month: month,
            day: day,
            category: CardCategory(rawValue: category) ?? .history,
            imageURL: imageURL,
            hint: hint
        )
    }
}