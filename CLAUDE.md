# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start for New Developers

### 1. Setup Quality Gates
```bash
# Install git hooks and SwiftLint (required for all contributors)
./scripts/setup-git-hooks.sh
```

### 2. Development Workflow
```bash
# Fast rebuild and relaunch in simulator
./run.sh

# Quick relaunch without rebuilding (if no code changes)
./launch.sh
```

## Build & Run Commands

### iOS Simulator (Xcode 15+)
```bash
# Build the app
xcodebuild \
  -package-path . \
  -scheme WorkoutTracker \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build \
  INFOPLIST_FILE=Sources/WorkoutTracker/Info.plist \
  clean build

# Install and launch in simulator
APP_PATH="build/Build/Products/Debug-iphonesimulator/WorkoutTracker.app"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.yourcompany.WorkoutTracker
```

### Xcode Development
Open `Package.swift` in Xcode and configure the scheme:
- Uncheck "Generate Info.plist File" 
- Check "Use Info.plist File" and select `Sources/WorkoutTracker/Info.plist`

## Architecture Overview

This is a SwiftUI-based iOS workout tracker using Swift Package Manager with a clean MVVM architecture:

### Data Flow
- **Models**: `ExerciseEntry` and `ExerciseSet` are simple Codable structs
- **DataStore**: Handles JSON persistence to local Documents directory using ISO8601 date encoding
- **WorkoutViewModel**: Single ObservableObject that manages all exercise entries and coordinates with DataStore
- **Views**: SwiftUI views receive the ViewModel via `@EnvironmentObject` from the app root

### Key Architectural Patterns
- **Single Source of Truth**: `WorkoutViewModel` is injected at app root and shared across all views
- **Automatic Persistence**: All data mutations (add/delete) automatically trigger save to disk
- **Platform Conditionals**: Uses `#if canImport(UIKit)` for iOS-specific features like ActivityView
- **Tab-Based Navigation**: Main interface uses TabView with sheets for modals

### Data Persistence
- Local JSON storage in Documents directory (`workout_entries.json`)
- Export functionality creates shareable JSON files
- ISO8601 date encoding for cross-platform compatibility

### Important Files
- `WorkoutTrackerApp.swift`: App entry point that injects ViewModel
- `DataStore.swift`: All persistence logic isolated here
- `WorkoutViewModel.swift`: Central state management
- `ContentView.swift`: Main tab interface and modal coordination

## Quality Gates

This project enforces code quality through automated checks:

### Pre-commit Hooks
- **SwiftLint**: Enforces Swift style guidelines and catches common issues
- **Compilation Check**: Verifies staged Swift files compile successfully
- **Fast Execution**: Uses lightweight checks (< 5 seconds) to avoid slowing commits

### Setup for New Team Members
Run `./scripts/setup-git-hooks.sh` to automatically install all quality gates.

### Manual Quality Checks
```bash
# Run SwiftLint manually
swiftlint

# Auto-fix style violations
swiftlint --fix

# Test full build
./run.sh
```

The quality gates prevent broken code and style violations from entering the repository, ensuring consistent code quality across all contributors.