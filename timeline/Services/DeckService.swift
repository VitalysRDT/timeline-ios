//
//  DeckService.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import FirebaseRemoteConfig
import Combine

final class DeckService: ObservableObject {
    static let shared = DeckService()
    
    @Published private(set) var cards: [Card] = []
    private let remoteConfig = RemoteConfig.remoteConfig()
    
    private init() {
        if let bundledCards = DeckService.loadBundledCards() {
            cards = bundledCards
        } else {
            cards = DeckService.generateDefaultCards()
        }
        setupRemoteConfig()
    }
    
    private static func loadBundledCards() -> [Card]? {
        let bundles: [Bundle] = [Bundle.main, Bundle(for: DeckService.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "cards", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decodedCards = try? JSONDecoder().decode([Card].self, from: data) {
                return decodedCards
            }
        }
        return nil
    }
    
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        
        remoteConfig.setDefaults(["cards_data": NSString(string: "[]")])
    }
    
    /// Fetch cards from Remote Config
    func fetchRemoteCards() async throws {
        try await remoteConfig.fetchAndActivate()
        
        let cardsData = remoteConfig["cards_data"].dataValue
        if let decodedCards = try? JSONDecoder().decode([Card].self, from: cardsData),
           !decodedCards.isEmpty {
            cards = decodedCards
        }
    }
    
    /// Generate a deterministic deck based on seed
    func generateDeck(seed: Int, count: Int = 50) -> [Card] {
        guard !cards.isEmpty else { return [] }
        var rng = SeededRandomNumberGenerator(seed: seed)
        let shuffledCards = cards.shuffled(using: &rng)
        let limit = min(count, shuffledCards.count)
        
        var categoryPools: [CardCategory: [Card]] = [:]
        for card in shuffledCards {
            categoryPools[card.category, default: []].append(card)
        }
        
        var deck: [Card] = []
        while deck.count < limit {
            let availableCategories = categoryPools.filter { !$0.value.isEmpty }.map { $0.key }
            guard !availableCategories.isEmpty,
                  let selectedCategory = availableCategories.randomElement(using: &rng),
                  var cardsForCategory = categoryPools[selectedCategory] else {
                break
            }
            deck.append(cardsForCategory.removeFirst())
            categoryPools[selectedCategory] = cardsForCategory
        }
        
        return deck
    }
    
    /// Get card by ID
    func getCard(id: String) -> Card? {
        cards.first { $0.id == id }
    }
    
    /// Generate default cards if no JSON available
    private static func generateDefaultCards() -> [Card] {
        let defaults: [Card] = [
            Card(title: "Invention de l'imprimerie", description: "Johannes Gutenberg invente l'imprimerie à caractères mobiles", year: 1440, category: .technology),
            Card(title: "Découverte de l'Amérique", description: "Christophe Colomb découvre le Nouveau Monde", year: 1492, month: 10, day: 12, category: .discovery),
            Card(title: "Révolution française", description: "Prise de la Bastille et début de la Révolution", year: 1789, month: 7, day: 14, category: .history),
            Card(title: "Premier vol motorisé", description: "Les frères Wright réalisent le premier vol motorisé", year: 1903, month: 12, day: 17, category: .technology),
            Card(title: "Théorie de la relativité", description: "Albert Einstein publie sa théorie de la relativité restreinte", year: 1905, category: .science),
            Card(title: "Première Guerre mondiale", description: "Début du premier conflit mondial", year: 1914, month: 7, day: 28, category: .history),
            Card(title: "Révolution russe", description: "Révolution d'Octobre et prise du pouvoir par les Bolcheviks", year: 1917, month: 10, category: .politics),
            Card(title: "Découverte de la pénicilline", description: "Alexander Fleming découvre la pénicilline", year: 1928, month: 9, category: .science),
            Card(title: "Seconde Guerre mondiale", description: "Début du second conflit mondial", year: 1939, month: 9, day: 1, category: .history),
            Card(title: "Premier ordinateur", description: "ENIAC, le premier ordinateur électronique", year: 1946, category: .technology),
            Card(title: "Structure de l'ADN", description: "Découverte de la structure en double hélice de l'ADN", year: 1953, category: .science),
            Card(title: "Premier satellite artificiel", description: "Lancement de Spoutnik 1 par l'URSS", year: 1957, month: 10, day: 4, category: .technology),
            Card(title: "Premier homme dans l'espace", description: "Youri Gagarine devient le premier homme dans l'espace", year: 1961, month: 4, day: 12, category: .discovery),
            Card(title: "Premier pas sur la Lune", description: "Neil Armstrong marche sur la Lune", year: 1969, month: 7, day: 20, category: .discovery),
            Card(title: "Création d'Internet", description: "ARPANET, l'ancêtre d'Internet", year: 1969, month: 10, day: 29, category: .technology),
            Card(title: "Premier ordinateur personnel", description: "Apple II, l'un des premiers ordinateurs personnels", year: 1977, category: .technology),
            Card(title: "Chute du mur de Berlin", description: "Fin de la division de Berlin", year: 1989, month: 11, day: 9, category: .history),
            Card(title: "World Wide Web", description: "Tim Berners-Lee invente le World Wide Web", year: 1991, category: .technology),
            Card(title: "Premier iPhone", description: "Apple présente le premier iPhone", year: 2007, month: 1, day: 9, category: .technology),
            Card(title: "Construction des pyramides", description: "Construction de la pyramide de Khéops", year: -2560, category: .history),
            Card(title: "Fondation de Rome", description: "Selon la légende, Romulus fonde Rome", year: -753, month: 4, day: 21, category: .history),
            Card(title: "Naissance de Jésus", description: "Naissance du Christ selon la tradition chrétienne", year: 0, category: .history),
            Card(title: "Chute de l'Empire romain", description: "Fin de l'Empire romain d'Occident", year: 476, category: .history),
            Card(title: "Couronnement de Charlemagne", description: "Charlemagne couronné empereur", year: 800, month: 12, day: 25, category: .history),
            Card(title: "Bataille d'Hastings", description: "Guillaume le Conquérant envahit l'Angleterre", year: 1066, month: 10, day: 14, category: .history),
            Card(title: "Magna Carta", description: "Signature de la Grande Charte en Angleterre", year: 1215, month: 6, day: 15, category: .politics),
            Card(title: "Peste noire", description: "Pandémie de peste en Europe", year: 1347, category: .history),
            Card(title: "Renaissance italienne", description: "Début de la Renaissance en Italie", year: 1400, category: .culture),
            Card(title: "Guerre de Cent Ans", description: "Fin de la guerre entre France et Angleterre", year: 1453, category: .history),
            Card(title: "Réforme protestante", description: "Martin Luther publie ses 95 thèses", year: 1517, month: 10, day: 31, category: .history),
            Card(title: "Bataille de Lépante", description: "Victoire chrétienne contre l'Empire ottoman", year: 1571, month: 10, day: 7, category: .history),
            Card(title: "Défaite de l'Invincible Armada", description: "Défaite de la flotte espagnole", year: 1588, category: .history),
            Card(title: "Guerre de Trente Ans", description: "Début du conflit européen", year: 1618, category: .history),
            Card(title: "Siècle des Lumières", description: "Mouvement philosophique européen", year: 1700, category: .culture),
            Card(title: "Déclaration d'indépendance américaine", description: "Les États-Unis déclarent leur indépendance", year: 1776, month: 7, day: 4, category: .politics),
            Card(title: "Révolution industrielle", description: "Début de la révolution industrielle en Angleterre", year: 1760, category: .technology),
            Card(title: "Bataille de Waterloo", description: "Défaite finale de Napoléon", year: 1815, month: 6, day: 18, category: .history),
            Card(title: "Abolition de l'esclavage", description: "Abolition de l'esclavage aux États-Unis", year: 1865, category: .politics),
            Card(title: "Téléphone", description: "Alexander Graham Bell invente le téléphone", year: 1876, category: .technology),
            Card(title: "Ampoule électrique", description: "Thomas Edison perfectionne l'ampoule électrique", year: 1879, category: .technology),
            Card(title: "Automobile", description: "Karl Benz brevète la première automobile", year: 1886, category: .technology),
            Card(title: "Cinématographe", description: "Les frères Lumière inventent le cinématographe", year: 1895, category: .technology),
            Card(title: "Radioactivité", description: "Henri Becquerel découvre la radioactivité", year: 1896, category: .science),
            Card(title: "Aspirine", description: "Bayer commercialise l'aspirine", year: 1899, category: .science),
            Card(title: "Titanic", description: "Naufrage du Titanic", year: 1912, month: 4, day: 15, category: .history),
            Card(title: "Grippe espagnole", description: "Pandémie mondiale de grippe", year: 1918, category: .history),
            Card(title: "Découverte du tombeau de Toutânkhamon", description: "Howard Carter découvre le tombeau", year: 1922, month: 11, category: .discovery),
            Card(title: "Télévision", description: "John Logie Baird fait la première démonstration de télévision", year: 1926, category: .technology),
            Card(title: "Crise de 1929", description: "Krach boursier et début de la Grande Dépression", year: 1929, month: 10, day: 24, category: .history),
            Card(title: "Guerre civile espagnole", description: "Début du conflit en Espagne", year: 1936, month: 7, category: .history)
        ]
        return defaults.enumerated().map { index, card in
            Card(
                id: "default_\(index)",
                title: card.title,
                description: card.description,
                year: card.year,
                month: card.month,
                day: card.day,
                category: card.category,
                imageURL: card.imageURL,
                hint: card.hint
            )
        }
    }
}

/// Seeded random number generator for deterministic shuffling
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var seed: UInt64
    
    init(seed: Int) {
        self.seed = UInt64(abs(seed))
    }
    
    mutating func next() -> UInt64 {
        seed = (seed &* 1664525) &+ 1013904223
        return seed
    }
}