# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives in `timeline/` with MVVM folders: `Models/` (Card, Game), `Services/` (AuthService, GameService, DeckService, AudioHapticsService, SoloGameService), `ViewModels/AppState.swift`, and `Views/` for screen-level components (HomeView, GameView, LobbyView, ResultsView, etc.). Shared assets and JSON seeds sit in `Assets.xcassets` and `cards.json`. Integration templates such as `firebase.json`, `remoteconfig.template.json`, and Firestore rules are at the repo root, while UI tests currently reside in `timelineTests/`.

## Build, Test, and Development Commands
Open `timeline.xcodeproj` and build with the `timeline` scheme (`⌘R`) for simulator or device. CLI builds use `xcodebuild -project timeline.xcodeproj -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15' build`. Run the XCTest suite with `xcodebuild test` using the same destination. Deploy updated Firestore rules through `firebase deploy --only firestore:rules` and keep `GoogleService-Info.plist` aligned with the active Firebase project.

## Coding Style & Naming Conventions
Match the existing Swift style: four-space indentation, trailing commas only for multiline literal cases, and type names in `UpperCamelCase` while properties/functions stay `lowerCamelCase`. Keep enums backed by raw values uppercase (e.g., `CardCategory`) and prefer `struct` for immutable models. Group SwiftUI views by feature inside `Views/` and keep view models `final class` implementations inside `ViewModels/`. Document non-obvious logic with concise comments and avoid storing secrets in source.

## Testing Guidelines
Add or update tests in `timelineTests/`, mirroring the feature under test (e.g., deck logic in `DeckServiceTests`). Name methods with `testGiven_When_Then` clarity and cover edge cases like negative years or deterministic shuffling. Ensure any new service logic is reproducible by injecting seeds or fixtures. Run the full suite via Xcode or the `xcodebuild test` command before opening a PR.

## Commit & Pull Request Guidelines
Write commits in imperative mood under 72 characters, following the existing style (`Add deck balancing tests`). Bundle related changes, mention Firebase or config impacts in the body, and reference issues with `#id` when relevant. PRs should describe the feature, outline testing steps, and include simulator screenshots for UI work. Call out Firebase schema adjustments or migration steps explicitly so reviewers can apply them locally.

## Security & Configuration Tips
Never commit real Firebase keys; rely on the provided templates and document changes in `README.md`. When modifying remote config or Firestore structure, update the corresponding JSON files and note rollout instructions in the PR. Verify App Check and anonymous auth remain enabled in any new environments before shipping multiplayer features.
