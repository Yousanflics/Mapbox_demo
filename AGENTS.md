# Repository Guidelines

## Project Structure & Module Organization
Mapbox_tutorial/ hosts the SwiftUI target: `Mapbox_tutorialApp.swift` wires `ContentView.swift`, while `Map/MapViewController.swift` and `Map/MapViewWrapper.swift` own Mapbox initialization, layer wiring, and offline downloads. UI overlays live under `Views/` (controls, popups, offline panels). Static data, including `Resources/routes.geojson` and `Assets.xcassets`, feed map content. Reference `Doc/Mapbox_start.md` for a deeper architecture brief, and keep logic tests in `Mapbox_tutorialTests` with UI automation in `Mapbox_tutorialUITests`.

## Build, Test & Development Commands
- `xed Mapbox_tutorial.xcodeproj` – opens the project with the `Mapbox_tutorial` scheme preselected and resolves SPM dependencies.
- `xcodebuild -scheme Mapbox_tutorial -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` – headless build that surfaces Swift, Mapbox, and asset warnings before review.
- `xcodebuild test -scheme Mapbox_tutorial -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` – runs the async logic tests defined with the `Testing` framework.
- `xcodebuild test -scheme Mapbox_tutorialUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` – launches the UI suite (including `testLaunchPerformance`).

## Coding Style & Naming Conventions
Stick to Swift 5.9 defaults: 4-space indentation, trailing commas for multiline collections, and 120-character soft wraps. Views, controllers, and models should end with `View`, `Controller`, or `Annotation` respectively, while helper structs use UpperCamelCase and properties/methods use lowerCamelCase. Keep SwiftUI `@State` and bindings grouped by feature, mirror file names (e.g., `MapControlsView` in `MapControlsView.swift`), and store data files with descriptive snake_case names in `Resources/`.

## Testing Guidelines
Unit tests leverage the lightweight `Testing` package—annotate functions with `@Test`, prefer `async throws`, and assert via `#expect` so failures explain the map condition being validated. UI coverage stays in XCTest; prefix methods with `test` and reset simulator state in `setUpWithError`. Target error-handling of downloads (progress, cancellation, recovery) and geography filters before merging.

## Commit & Pull Request Guidelines
History currently uses short imperative subjects (e.g., “Initial Commit”), so continue writing a concise verb-led title under 60 characters; add optional scopes like `feat:` or `fix:` when batching UI work. Describe what changed, why, and how to verify (`xcodebuild` commands, screenshots of overlays/states). Every PR should link related issues, call out Mapbox token requirements, attach simulator screenshots for visual tweaks, and mention any offline regions or routes that need regenerating.

## Security & Configuration Tips
Do not hardcode real Mapbox tokens. Store local values via `MBXAccessToken` in an untracked config or use `MapboxOptions.accessToken` from environment variables, then document the setup in the PR. Keep sample data like `routes.geojson` sanitized, and avoid committing device-specific settings from `xcuserdata`.
