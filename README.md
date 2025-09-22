# Timeline - Jeu iOS Multijoueur

Application iOS native développée en Swift/SwiftUI offrant un jeu de placement chronologique d'événements historiques avec mode multijoueur en ligne via Firebase.

## Configuration requise

- iOS 16.0+
- Xcode 15.0+
- Compte Firebase avec projet configuré

## Installation

### 1. Configuration Firebase

1. Créer un projet Firebase sur [console.firebase.google.com](https://console.firebase.google.com)
2. Activer les services suivants :
   - Authentication (mode anonyme)
   - Cloud Firestore
   - Remote Config
   - App Check (DeviceCheck)
   - Crashlytics

3. Télécharger le fichier `GoogleService-Info.plist`
4. Ajouter le fichier au projet Xcode dans le dossier `timeline/`

### 2. Configuration Firestore

Déployer les règles de sécurité :
```bash
firebase deploy --only firestore:rules
```

### 3. Build et Run

1. Ouvrir `timeline.xcodeproj` dans Xcode
2. Sélectionner la cible et le simulateur/device
3. Build and Run (⌘R)

## Architecture

### Structure MVVM

```
timeline/
├── Models/          # Modèles de données
├── Services/        # Services (Auth, Game, Deck, Audio)
├── ViewModels/      # ViewModels (AppState)
├── Views/           # Vues SwiftUI
└── Resources/       # Assets et fichiers JSON
```

### Services principaux

- **AuthService** : Gestion de l'authentification anonyme Firebase
- **GameService** : Logique de jeu et synchronisation temps réel
- **DeckService** : Gestion des cartes et génération de deck
- **AudioHapticsService** : Sons et retours haptiques

## Schéma Firestore

### Collections

```
games/{gameId}
  - status: "lobby" | "running" | "finished"
  - createdAt: timestamp
  - startsAt: timestamp
  - currentRound: number
  - maxPlayers: number
  - deckSeed: number
  - playersCount: number
  - aliveCount: number
  - hostId: string

games/{gameId}/players/{playerId}
  - displayName: string
  - isHost: boolean
  - isEliminated: boolean
  - joinedAt: timestamp
  - lastSeenAt: timestamp
  - score: number
  - avgResponseMs: number
  - avatar: string

games/{gameId}/rounds/{roundIndex}
  - cardId: string
  - roundStartsAt: timestamp
  - roundEndsAt: timestamp
  - resolved: boolean
  - timelineBefore: array<string>

games/{gameId}/submissions/{roundIndex}_{playerId}
  - positionIndex: number
  - submittedAt: timestamp
  - isCorrect: boolean
  - latencyMs: number
```

## Synchronisation des timers

L'application utilise une calibration du temps serveur pour synchroniser les timers entre tous les joueurs :

1. Au démarrage, calibration via `FieldValue.serverTimestamp()`
2. Calcul de l'offset entre temps local et serveur
3. Application de l'offset sur tous les timers locaux
4. Précision de synchronisation : ±200ms

## Gameplay

### Mode Solo (non implémenté)
- Entraînement local avec cartes stockées

### Mode Multijoueur
1. **Lobby** : Compte à rebours de 60s dès le premier joueur
2. **Partie** : Rounds de 30s synchronisés
3. **Placement** : Drag & drop de la carte sur la frise
4. **Validation** : Vérification chronologique stricte
5. **Élimination** : Mauvais placement = mode spectateur
6. **Victoire** : Dernier joueur non éliminé

## Deep Links

Format : `timeline://join?gameId={gameId}`

Permet de rejoindre directement une partie via un lien partagé.

## Données de cartes

100 cartes historiques incluses dans `cards.json` avec :
- Événements historiques majeurs
- Découvertes scientifiques
- Inventions technologiques
- Faits culturels et politiques

Période couverte : -2560 (Pyramides) à 2022 (ChatGPT)

## Tests

Tests unitaires disponibles pour :
- Comparaison chronologique des cartes
- Génération déterministe de deck
- Logique de validation des placements
- Cas limites (dates négatives, dates identiques)

## Limites connues

- Pas de Cloud Functions : validation côté client + règles Firestore
- Mode solo non finalisé
- Pas de système de progression/niveaux
- Pas de personnalisation d'avatar avancée
- Sons non fournis (fichiers .wav à ajouter)

## Performance

- Animations 60 FPS via SwiftUI spring animations
- Lazy loading des cartes dans la frise
- Batch Firestore pour les écritures multiples
- Cache local des parties récentes

## Sécurité

- Authentication anonyme obligatoire
- Règles Firestore strictes
- App Check activé (DeviceCheck/Debug provider)
- Validation côté serveur via règles
- Pas de données sensibles stockées

## Contact

Pour toute question ou problème, créer une issue sur le repository.