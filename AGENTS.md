# Repository Guidelines

## Project Structure & Module Organization

ShortClip is a macOS 14+ menu bar app built with Swift Package Manager. `Sources/ShortClipCore/` contains domain models, application logic, and persistence; keep reusable behavior there. `Sources/ShortClipApp/App/` holds macOS integrations and app state, while `Sources/ShortClipApp/UI/` contains SwiftUI views. Matching tests live in `Tests/ShortClipCoreTests/` and `Tests/ShortClipAppTests/`. `App/Info.plist` supplies bundle metadata, and `Scripts/build-app.sh` packages the app. Treat `.build/` and `dist/` as generated output.

## Build, Test, and Development Commands

- `swift run ShortClipApp` starts the menu bar app locally.
- `swift build` compiles both package targets.
- `swift test` runs the full Swift Testing suite.
- `swift test --filter SnippetStoreTests` runs a focused test suite.
- `zsh ./Scripts/build-app.sh` creates an ad hoc signed `dist/ShortClip.app` for local use.

Use a Swift 6 toolchain. If Command Line Tools cannot resolve `import Testing`, use the framework search path shown in `README.md`.

## Coding Style & Naming Conventions

Follow the existing Swift style: two-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for properties, functions, and test methods. Prefer value types, focused functions, early `guard` returns, and explicit dependencies for clocks or system services. Put platform-independent rules in `ShortClipCore` and macOS APIs in `ShortClipApp`. No formatter or linter is configured; keep changes consistent with nearby files.

## Testing Guidelines

Tests use Swift Testing (`import Testing`, `@Test`, and `#expect`). Name files after the behavior under test, such as `SnippetStoreTests.swift`, and name test functions for the expected outcome. Add or update tests when changing behavior, then run `swift test`. There is no stated coverage threshold.

## Commit & Pull Request Guidelines

The short Git history does not establish a commit format. Use a concise, descriptive subject in the imperative mood. Pull requests should explain the user-visible change, link any relevant issue, and include `swift test` results. Add screenshots or a short recording for UI changes. Before a release, also run `zsh ./Scripts/build-app.sh`.

## Privacy & Security

Clipboard history stays in memory; snippets are encrypted on disk with a Keychain-held key. Do not log clipboard or snippet text, and keep generated files and local secrets out of commits.
