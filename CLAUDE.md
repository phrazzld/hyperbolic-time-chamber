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
- **Package.swift Validation**: Verifies Swift Package Manager syntax and dependency resolution
- **SwiftLint**: Enforces Swift style guidelines and catches common issues
- **Compilation Check**: Verifies staged Swift files compile successfully
- **Fast Execution**: Uses lightweight checks (< 10 seconds) to avoid slowing commits

### Setup for New Team Members
Run `./scripts/setup-git-hooks.sh` to automatically install all quality gates.

### Manual Quality Checks
```bash
# Validate Package.swift syntax
swift package resolve

# Run SwiftLint manually
swiftlint

# Auto-fix style violations
swiftlint --fix

# Test full build
./run.sh
```

## Package Management Guidelines

### Package.swift Best Practices
- **Always validate syntax** before committing with `swift package resolve`
- **Avoid trailing commas** in target arrays and dependency lists
- **Use semantic versioning** for external dependencies (e.g., `from: "1.15.0"`)
- **Group related targets together** for better organization
- **Test dependency resolution** after any Package.swift changes

### Common Package.swift Issues
- Missing commas between array elements
- Trailing commas in target or dependency arrays
- Invalid target name references
- Incorrect dependency specifications
- Missing path specifications for non-standard directory structures

### Troubleshooting Package Issues
```bash
# View detailed dependency resolution errors
swift package resolve

# Show dependency graph
swift package show-dependencies

# Clean and rebuild package cache
swift package clean
swift package resolve
```

The quality gates prevent broken Package.swift files, code style violations, and compilation errors from entering the repository, ensuring consistent code quality and reliable dependency management across all contributors.