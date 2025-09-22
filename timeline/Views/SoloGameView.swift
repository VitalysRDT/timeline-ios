//
//  SoloGameView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI

struct SoloGameView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var soloService = SoloGameService.shared
    @State private var selectedDifficulty: SoloGameService.Difficulty = .normal
    @State private var selectedInsertIndex: Int? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var showHint = false
    @State private var hintIndex: Int?
    @State private var showStats = false
    @State private var showErrorAnimation = false
    @State private var lastWrongCardId: String? = nil
    @State private var wrongCardIds: Set<String> = []  // Stocker les IDs des cartes mal placées
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.green.opacity(0.8), Color.teal.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            switch soloService.gameState {
            case .menu:
                menuView
            case .playing:
                gameView
            case .gameOver:
                gameOverView
            case .victory:
                victoryView
            }
        }
    }
    
    private var menuView: some View {
        VStack(spacing: 20) {
            Text("Mode Solo")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            Text("Choisissez votre difficulté")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 12) {
                ForEach(SoloGameService.Difficulty.allCases, id: \.self) { difficulty in
                    Button(action: {
                        AudioHapticsService.shared.haptic(.selection)
                        selectedDifficulty = difficulty
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(difficulty.rawValue)
                                    .font(.headline)
                                
                                HStack {
                                    Label("\(difficulty.lives) vies", systemImage: "heart.fill")
                                    Label("\(difficulty.cardCount) cartes", systemImage: "square.stack.fill")
                                }
                                .font(.caption)
                            }
                            
                            Spacer()
                            
                            if selectedDifficulty == difficulty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            selectedDifficulty == difficulty ?
                            Color.white.opacity(0.3) : Color.white.opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundColor(.white)
                }
                
                let highScore = HighScoreManager.shared.getHighScore(for: selectedDifficulty)
                if highScore > 0 {
                    Text("Meilleur score: \(highScore)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            
            HStack(spacing: 16) {
                Button(action: {
                    AudioHapticsService.shared.haptic(.light)
                    appState.navigateTo(.home)
                }) {
                    Label("Retour", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    AudioHapticsService.shared.haptic(.medium)
                    soloService.startNewGame(difficulty: selectedDifficulty)
                }) {
                    Label("Commencer", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if !HighScoreManager.shared.getHighScores().isEmpty {
                Button(action: {
                    showStats = true
                }) {
                    Label("Meilleurs scores", systemImage: "trophy.fill")
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showStats) {
            HighScoresView()
        }
    }
    
    private var gameView: some View {
        VStack(spacing: 0) {
            gameHeader
            
            if let card = soloService.currentCard {
                currentCardView(card: card)
            }
            
            Spacer(minLength: 10)
            
            timelineView
            
            Spacer(minLength: 10)
            
            // Section des statistiques pour combler l'espace
            statsSection
            
            gameControls
        }
    }
    
    private var gameHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("x\(soloService.lives)")
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(soloService.score) pts")
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Cartes: \(soloService.timeline.count)/\(soloService.difficulty.cardCount)")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Série: \(soloService.streak)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    private func currentCardView(card: Card) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                Text(card.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)  // Pas de limite de lignes
                    .fixedSize(horizontal: false, vertical: true)  // Permettre l'expansion verticale
                
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)  // Pas de limite de lignes
                        .fixedSize(horizontal: false, vertical: true)  // Permettre l'expansion verticale
                }
                
                if let hint = card.hint, showHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .italic()
                }
                
                HStack {
                    Circle()
                        .fill(Color(hex: card.category.color) ?? .blue)
                        .frame(width: 8, height: 8)
                    
                    Text(card.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .frame(width: 220, height: 140)  // Taille fixe pour eviter les problemes
            .background(
                LinearGradient(
                    colors: [(Color(hex: card.category.color) ?? .blue).opacity(0.8), (Color(hex: card.category.color) ?? .blue).opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 5)
            
            if let nextCard = soloService.nextCard {
                HStack {
                    Text("Prochaine:")
                        .font(.caption)
                    Text(nextCard.title)
                        .font(.caption.bold())
                }
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            }
        }
        .padding()
    }
    
    private var timelineView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            timelineContent
                .background(scrollOffsetReader)
        }
        .frame(height: 140)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(SoloScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            showErrorAnimation ?
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.red, lineWidth: 3)
                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: showErrorAnimation) :
            nil
        )
        .padding(.horizontal)
        .shake(animatableData: showErrorAnimation ? 1 : 0)
    }
    
    private var timelineContent: some View {
        HStack(spacing: 8) {
            ForEach(0...soloService.timeline.count, id: \.self) { index in
                HStack(spacing: 8) {
                    // Bouton d'insertion avant chaque carte (et après la dernière)
                    SoloInsertButton(
                        index: index,
                        isSelected: selectedInsertIndex == index,
                        isHint: hintIndex == index && showHint,
                        action: {
                            insertCard(at: index)
                        }
                    )
                    
                    // Afficher la carte si ce n'est pas le dernier index
                    if index < soloService.timeline.count {
                        let card = soloService.timeline[index]
                        SoloTimelineCardView(
                            card: card,
                            isWrong: wrongCardIds.contains(card.id)
                        )
                        .frame(width: 100, height: 120)
                    }
                }
            }
        }
        .padding()
    }
    
    private func insertCard(at index: Int) {
        selectedInsertIndex = index
        submitPlacement(at: index)
        
        // Réinitialiser après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedInsertIndex = nil
        }
    }
    
    private var scrollOffsetReader: some View {
        GeometryReader { innerGeometry in
            Color.clear
                .preference(key: SoloScrollOffsetPreferenceKey.self, value: -innerGeometry.frame(in: .named("scroll")).minX)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            // Barre de progression
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progression")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(soloService.timeline.count)/30 cartes")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (CGFloat(soloService.timeline.count) / 30.0))
                    }
                }
                .frame(height: 8)
            }
            
            // Statistiques en temps réel
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Série")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(soloService.currentStreak)")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 4) {
                    Text("Précision")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(soloService.accuracy))%")
                        .font(.title3.bold())
                        .foregroundColor(.cyan)
                }
                
                VStack(spacing: 4) {
                    Text("Meilleure série")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(soloService.bestStreak)")
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
            )
        }
        .padding(.horizontal)
    }
    
    private var gameControls: some View {
        HStack(spacing: 16) {
            Button(action: {
                AudioHapticsService.shared.playHintSound()
                if let index = soloService.useHint() {
                    hintIndex = index
                    showHint = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        hintIndex = nil
                        showHint = false
                    }
                }
            }) {
                Label("Indice (-50 pts)", systemImage: "lightbulb.fill")
                    .font(.caption)
                    .padding(8)
                    .background(Color.yellow.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                // Son d'avertissement pour passer une carte
                AudioHapticsService.shared.playSystemSoundWithVibration("elimination")
                soloService.skipCard()
            }) {
                Label("Passer (-1 vie)", systemImage: "forward.fill")
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                AudioHapticsService.shared.haptic(.light)
                soloService.returnToMenu()
                appState.navigateTo(.home)
            }) {
                Label("Quitter", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
    
    private var gameOverView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Partie terminée")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Score final: \(soloService.score)")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Cartes placées: \(soloService.timeline.count)")
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Meilleure série: \(soloService.bestStreak)")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 16) {
                Button(action: {
                    AudioHapticsService.shared.haptic(.light)
                    soloService.returnToMenu()
                }) {
                    Label("Menu", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    AudioHapticsService.shared.haptic(.medium)
                    soloService.startNewGame(difficulty: soloService.difficulty)
                }) {
                    Label("Rejouer", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
    
    private var victoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("Victoire!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Score final: \(soloService.score)")
                    .font(.title2.bold())
                    .foregroundColor(.yellow)
                
                Text("Toutes les cartes placées!")
                    .foregroundColor(.white)
                
                Text("Vies restantes: \(soloService.lives)")
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Meilleure série: \(soloService.bestStreak)")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 16) {
                Button(action: {
                    AudioHapticsService.shared.haptic(.light)
                    soloService.returnToMenu()
                }) {
                    Label("Menu", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    AudioHapticsService.shared.haptic(.medium)
                    soloService.startNewGame(difficulty: soloService.difficulty)
                }) {
                    Label("Nouvelle partie", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
    
    private func submitPlacement(at index: Int) {
        // Sauvegarder l'ID de la carte actuelle AVANT de la placer
        let currentCardId = soloService.currentCard?.id
        
        let isCorrect = soloService.placeCard(at: index)
        
        if isCorrect {
            AudioHapticsService.shared.playCardPlacement(isCorrect: true)
            // Retirer de la liste des cartes mal placées si elle y était
            if let cardId = currentCardId {
                wrongCardIds.remove(cardId)
            }
        } else {
            // Son et feedback pour mauvaise réponse
            AudioHapticsService.shared.playCardPlacement(isCorrect: false)
            
            // Animation d'erreur
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                showErrorAnimation = true
            }
            
            // Marquer la CARTE comme incorrecte (pas la position)
            // Note: En mode solo, quand on se trompe, la carte est placée au bon endroit
            // On doit donc retrouver où elle a été placée et la marquer
            if let cardId = currentCardId {
                lastWrongCardId = cardId
                wrongCardIds.insert(cardId)
            }
            
            // Réinitialiser l'animation après un délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showErrorAnimation = false
                }
            }
        }
    }
}

struct HighScoresView: View {
    @Environment(\.dismiss) var dismiss
    let highScores = HighScoreManager.shared.getHighScores()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.green.opacity(0.8), Color.teal.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(highScores.enumerated()), id: \.offset) { index, score in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading) {
                                    Text("\(score.score) points")
                                        .font(.headline)
                                    Text("\(score.difficulty) - \(score.cardsPlaced) cartes")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                
                                Spacer()
                                
                                Text(score.date, style: .date)
                                    .font(.caption)
                                    .opacity(0.6)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Meilleurs Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SoloScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Structure pour les cartes de la timeline solo
struct SoloTimelineCardView: View {
    let card: Card
    var isWrong: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(card.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isWrong ? .white.opacity(0.8) : .white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
            
            Spacer(minLength: 0)
            
            Text(card.formattedDate)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isWrong ? .red : .yellow)
            
            Circle()
                .fill(Color(hex: card.category.color) ?? .blue)
                .frame(width: 8, height: 8)
            
            if isWrong {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isWrong ?
                    LinearGradient(
                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isWrong ? Color.red : Color.white.opacity(0.3), lineWidth: isWrong ? 2 : 1)
        )
        .scaleEffect(isWrong ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isWrong)
    }
}

// Structure pour le bouton d'insertion en mode solo
struct SoloInsertButton: View {
    let index: Int
    let isSelected: Bool
    let isHint: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if isHint {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.yellow)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            isSelected ? Color.green :
                            Color.white.opacity(0.8)
                        )
                }
                
                if isHint {
                    Text("ICI")
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                } else {
                    Text("\(index)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 44, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isHint ? Color.yellow.opacity(0.3) :
                        isSelected ? Color.green.opacity(0.3) :
                        Color.white.opacity(0.15)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHint ? Color.yellow :
                        isSelected ? Color.green :
                        Color.white.opacity(0.3),
                        lineWidth: isHint || isSelected ? 2 : 1
                    )
            )
        }
        .scaleEffect(isHint ? 1.15 : (isSelected ? 1.1 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: isHint)
    }
}

// Modifier pour l'animation de shake
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shake(animatableData: CGFloat) -> some View {
        self.modifier(ShakeEffect(animatableData: animatableData))
    }
}

#Preview {
    SoloGameView()
        .environmentObject(AppState())
}