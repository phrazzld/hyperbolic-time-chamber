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

## CI Troubleshooting Guide

### Common CI Timeout Issues

If CI tests are timing out (e.g., at test 112/118), the following optimizations have been implemented:

#### 1. Extended Test Timeout
- CI test timeout increased from 120s to 180s in `pr-validation.yml`
- Uses `gtimeout 180s swift test` to prevent test hanging

#### 2. Enhanced CI Environment Detection
- Primary detection: `ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"`
- Removed unreliable generic "CI" environment variable
- More predictable CI behavior across different environments

#### 3. Optimized Performance Test Datasets
All performance tests in `LargeDatasetPerformanceTests.swift` use reduced datasets in CI:
- **CI datasets**: 20-50 entries maximum
- **Local datasets**: Full test coverage with 100-10,000 entries
- Dynamic sizing based on `isRunningInCI` property

#### 4. Conditional Compilation for Stress Tests
Stress tests are excluded in CI using `#if !CI_BUILD`:
- `testScalabilityAcrossDifferentDatasetSizes` (1000-5000 entries)
- `testExtremeDatasetStressTest` (up to 10,000 entries)
- CI build/test commands use `-Xswiftc -DCI_BUILD` flag

### CI-Specific Configurations

#### Build Commands
```bash
# CI builds with conditional compilation flag
swift build -Xswiftc -DCI_BUILD

# CI tests with conditional compilation flag
swift test -Xswiftc -DCI_BUILD --parallel
```

#### Environment Variables
- `GITHUB_ACTIONS=true` - Primary CI detection
- `CI_BUILD` - Compilation flag for excluding stress tests

### Debugging CI Failures

#### 1. Check Test Execution Logs
```bash
# View specific failing job logs
gh run view <run-id> --log-failed

# Check which test is hanging
gh run view <run-id> --log | grep "Test Case"
```

#### 2. Reproduce CI Environment Locally
```bash
# Run tests with CI optimizations
swift test -Xswiftc -DCI_BUILD

# Simulate CI environment
GITHUB_ACTIONS=true swift test -Xswiftc -DCI_BUILD
```

#### 3. Performance Test Analysis
If performance tests are still slow:
- Review dataset sizes in test methods
- Check for file I/O operations in CI
- Consider using in-memory data stores for CI
- Monitor test execution times with verbose output

#### 4. Common CI Failure Patterns
- **Timeout at test X/118**: Performance tests taking too long
- **Compilation timeout**: Complex expressions in test code
- **Memory issues**: Large datasets in constrained CI environment
- **File I/O bottlenecks**: Disk operations slower in CI

### CI Optimization Strategies

1. **Dataset Size Reduction**
   - Use `isRunningInCI` to conditionally reduce test data
   - Target 20-50 entries for CI, maintain full coverage locally

2. **Test Exclusion**
   - Use `#if !CI_BUILD` for stress/scalability tests
   - Keep core functionality tests always enabled

3. **In-Memory Operations**
   - Consider in-memory data stores for CI tests
   - Reduce file I/O operations where possible

4. **Parallel Execution**
   - Use `--parallel` flag for faster test execution
   - Monitor for race conditions in parallel tests

### Monitoring CI Performance

Track these metrics to ensure CI remains healthy:
- Total test execution time (target: < 3 minutes)
- Individual test execution times
- Memory usage during test runs
- Test count per suite

When adding new tests, always consider CI performance impact and apply appropriate optimizations.