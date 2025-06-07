# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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