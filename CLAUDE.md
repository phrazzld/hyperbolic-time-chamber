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

This is a SwiftUI-based iOS workout tracker using Swift Package Manager with a clean MVVM architecture and protocol-based dependency injection:

### Data Flow
- **Models**: `ExerciseEntry` and `ExerciseSet` are simple Codable structs with public APIs
- **DataStoreProtocol**: Abstraction defining data persistence operations (load, save, export)
- **DataStore Implementations**: 
  - `FileDataStore`: Production JSON persistence with security hardening and structured logging
  - `InMemoryDataStore`: Fast in-memory storage for testing and demos
- **DependencyFactory**: Environment-aware creation of ViewModels and DataStores
- **WorkoutViewModel**: Single ObservableObject that manages exercise entries via injected DataStore
- **Views**: SwiftUI views receive the ViewModel via `@EnvironmentObject` from the app root

### Key Architectural Patterns
- **Dependency Injection**: Protocol-based design enabling testability and environment flexibility
- **Single Source of Truth**: `WorkoutViewModel` is injected at app root and shared across all views
- **Environment-Aware Configuration**: Different DataStore implementations for production, testing, and demos
- **Automatic Persistence**: All data mutations (add/delete) automatically trigger save via injected DataStore
- **Protocol Extensions**: Convenient default methods with auto-generated correlation IDs
- **Security by Design**: Input validation, path traversal prevention, and graceful error handling
- **Platform Conditionals**: Uses `#if canImport(UIKit)` for iOS-specific features like ActivityView
- **Tab-Based Navigation**: Main interface uses TabView with sheets for modals

### Data Persistence
- **Production**: FileDataStore with local JSON storage in Documents directory (`workout_entries.json`)
- **Testing**: InMemoryDataStore for fast, isolated unit tests (50%+ speed improvement)
- **Demo/Screenshots**: InMemoryDataStore with pre-populated demo data
- **Export functionality**: Creates shareable JSON files via protocol interface
- **ISO8601 date encoding**: Cross-platform compatibility
- **Structured logging**: Comprehensive observability with correlation IDs
- **Security hardening**: Path traversal prevention, input validation, permission checks

### Environment Detection
The app automatically detects its runtime environment and configures appropriate dependencies:

```swift
// Production: Uses FileDataStore for persistent storage
let viewModel = try DependencyFactory.createViewModel()

// Testing: Uses InMemoryDataStore for fast, isolated tests  
let testConfig = DependencyFactory.Configuration(isUITesting: true)
let viewModel = try DependencyFactory.createViewModel(configuration: testConfig)

// Demo: Uses InMemoryDataStore with demo data
let demoConfig = DependencyFactory.Configuration(isDemo: true)
let viewModel = try DependencyFactory.createViewModel(configuration: demoConfig)
```

### Important Files
- `WorkoutTrackerApp.swift`: App entry point with dependency-injected ViewModel creation
- `DependencyFactory.swift`: Central factory for environment-aware dependency creation
- `DataStoreProtocol.swift`: Protocol defining data persistence interface and security errors
- `FileDataStore.swift`: Production implementation with security hardening and structured logging
- `InMemoryDataStore.swift`: Test/demo implementation for fast, isolated execution
- `WorkoutViewModel.swift`: Central state management with injected DataStore dependency
- `ContentView.swift`: Main tab interface and modal coordination

### Testing Architecture
- **Unit Tests**: Use `InMemoryDataStore` for fast, isolated testing without file I/O
- **Integration Tests**: Use `FileDataStore` with temporary directories
- **Dependency Injection Tests**: Verify `DependencyFactory` creates correct implementations
- **Security Tests**: Comprehensive validation of input sanitization and error handling
- **Test Data Factory**: Centralized creation of test data with environment-aware sizing

## New Developer Onboarding

### Understanding the Dependency Injection Architecture

This app uses **protocol-based dependency injection** to achieve clean separation of concerns and comprehensive testability. Here's what new developers need to know:

#### Core Concept: Protocol-Based Design
Instead of hardcoding specific implementations, the app depends on **protocols** (abstractions):

```swift
// ❌ Old approach: Hardcoded dependency
class WorkoutViewModel {
    private let dataStore = FileDataStore()  // Hard to test!
}

// ✅ New approach: Injected protocol
class WorkoutViewModel {
    private let dataStore: DataStoreProtocol  // Easy to test!
    
    init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
    }
}
```

#### Why This Matters for New Developers

1. **Testing**: You can easily inject test doubles for fast, isolated tests
2. **Flexibility**: Different environments (production, testing, demo) use different implementations
3. **Security**: Graceful fallbacks when storage initialization fails
4. **Performance**: Tests run 50%+ faster without file I/O

#### Quick Start for Development

1. **Run Setup Script**:
   ```bash
   ./scripts/setup-git-hooks.sh
   ```

2. **Start Development**:
   ```bash
   # Fast rebuild and launch
   ./run.sh
   ```

3. **Understand Test Patterns**:
   ```swift
   // In your tests, use InMemoryDataStore for speed
   func testSomething() {
       let dataStore = InMemoryDataStore()
       let viewModel = WorkoutViewModel(dataStore: dataStore)
       // Test without touching the file system
   }
   ```

#### Environment-Aware Development

The app automatically detects its environment:

- **Xcode Development**: Uses `FileDataStore` for real persistence
- **Unit Tests**: Uses `InMemoryDataStore` for fast execution  
- **UI Tests**: Uses `InMemoryDataStore` for isolated scenarios
- **Screenshot/Demo Mode**: Uses `InMemoryDataStore` with demo data

You don't need to manually configure this - `DependencyFactory.createViewModel()` handles it automatically.

#### Adding New Features

When adding new features that need data persistence:

1. **Use the existing DataStoreProtocol**: Don't create new storage mechanisms
2. **Inject dependencies**: Accept protocols, not concrete types
3. **Write tests first**: Use `InMemoryDataStore` in your tests
4. **Follow existing patterns**: Look at `WorkoutViewModel` for examples

#### Common Patterns You'll See

```swift
// 1. Dependency injection in initializers
init(dataStore: DataStoreProtocol) { ... }

// 2. Protocol extensions for convenience  
dataStore.load()  // Auto-generates correlation ID
dataStore.load(correlationId: "custom-id")  // Explicit correlation ID

// 3. Environment-aware factory usage
let viewModel = try DependencyFactory.createViewModel()

// 4. Test setup with InMemoryDataStore
let testStore = InMemoryDataStore(entries: testData)
let viewModel = WorkoutViewModel(dataStore: testStore)
```

#### Key Files to Understand

For new developers, focus on understanding these files in order:

1. **`DataStoreProtocol.swift`**: The core abstraction - start here
2. **`DependencyFactory.swift`**: How dependencies are created
3. **`WorkoutViewModel.swift`**: How business logic uses injected dependencies
4. **`WorkoutTrackerApp.swift`**: How the app wires everything together
5. **`DependencyInjectionExampleTests.swift`**: Practical examples of testing patterns

#### Reference Documentation

- **[DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)**: Comprehensive DI documentation with examples
- **Testing Patterns**: See `Tests/WorkoutTrackerTests/DependencyInjectionExampleTests.swift`
- **Architecture Deep Dive**: See the Architecture Overview section above

## Quality Gates

This project enforces code quality through automated checks:

### Pre-commit Hooks
- **Package.swift Validation**: Verifies Swift Package Manager syntax and dependency resolution
- **SwiftLint**: Enforces Swift style guidelines and catches common issues
- **Compilation Check**: Verifies staged Swift files compile successfully
- **Fast Execution**: Uses lightweight checks (< 10 seconds) to avoid slowing commits

### Test Execution Monitoring & Caching
- **Environment-Aware Execution**: CI uses sequential execution, local uses parallel
- **Intelligent Test Caching**: Automated caching of test results for unchanged code
  - **Build Artifact Caching**: Swift compilation artifacts cached between CI runs
  - **Test Result Caching**: Complete test results cached with source hash validation
  - **Selective Test Execution**: Only run tests affected by changed files
  - **Cache Validation**: 7-day cache TTL with environment and version checks
- **Timeout Warning System**: Proactive warnings at 75% and 100% of timeout thresholds
  - **CI Environment**: Early warning at 67.5s, final warning at 90s
  - **Local Environment**: Early warning at 135s, final warning at 180s
- **Real-Time Monitoring**: Continuous tracking of test execution with actionable guidance
- **Comprehensive Reporting**: Post-execution statistics including timeout threshold analysis

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

# Test with timeout monitoring
./scripts/run-tests.sh --verbose

# Test with intelligent caching (automatically detects changes)
./scripts/cached-test-runner.sh --verbose

# Force fresh test run (ignore cache)
./scripts/cached-test-runner.sh --force-full --coverage

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

## Testing Guidelines & @testable Import Best Practices

### Release Build Compatibility

**Critical Rule**: Test modules that must support release builds (like `TestConfiguration`) should NEVER use `@testable import`.

#### Why @testable Import Fails in Release Builds
- **Compilation Context**: `@testable import` requires modules to be compiled with testing symbols
- **Release Optimization**: Release builds strip testing symbols for performance and security
- **CI Validation**: All validation workflows test both debug AND release configurations
- **Production Readiness**: Release builds must work without test-specific modifications

#### Test Configuration Module Pattern

**✅ Correct Pattern: Public API with Regular Import**
```swift
// In Sources/WorkoutTracker/Models/ExerciseEntry.swift
public struct ExerciseEntry: Identifiable, Codable {
    public var id = UUID()
    public var exerciseName: String
    public var date: Date
    public var sets: [ExerciseSet]
    
    public init(exerciseName: String, date: Date, sets: [ExerciseSet]) {
        self.exerciseName = exerciseName
        self.date = date
        self.sets = sets
    }
}

// In Tests/TestConfiguration/WorkoutTestDataFactory.swift
import Foundation
import WorkoutTracker  // ✅ Regular import

public struct WorkoutTestDataFactory {
    public static func createBasicEntry() -> ExerciseEntry {
        ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
    }
}
```

**❌ Incorrect Pattern: @testable Import**
```swift
// In Tests/TestConfiguration/WorkoutTestDataFactory.swift
import Foundation
@testable import WorkoutTracker  // ❌ Fails in release builds

public struct WorkoutTestDataFactory {
    public static func createBasicEntry() -> ExerciseEntry {
        // This works in debug but FAILS in release builds
        ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
    }
}
```

### Public API Design Guidelines

#### When to Make Types Public

**Make types public when they are:**
1. **Used by test configuration modules** that support release builds
2. **Part of the core domain model** that other modules need to access
3. **Essential for cross-module testing** patterns

**Keep types internal when they are:**
1. **Implementation details** not needed outside the module
2. **Only used within unit tests** in the same module
3. **Internal utilities** that don't need external access

#### Public API Best Practices

```swift
// ✅ Complete public interface for test access
public struct ExerciseSet: Identifiable, Codable {
    public var id = UUID()
    public var reps: Int
    public var weight: Double?
    public var notes: String?

    // ✅ Public initializer for test data creation
    public init(reps: Int, weight: Double? = nil, notes: String? = nil) {
        self.reps = reps
        self.weight = weight
        self.notes = notes
    }
}
```

### Testing Architecture Patterns

#### Test Configuration Modules

**Purpose**: Centralized test data factories that work across all build configurations

**Structure**:
- `Tests/TestConfiguration/` - Shared test utilities
- Uses regular `import` statements only
- Provides public APIs for test data creation
- Works in both debug and release builds

#### Test Data Factory Pattern

```swift
public struct WorkoutTestDataFactory {
    // Environment-aware test data sizing
    public static func createLargeDataset(count: Int) -> [ExerciseEntry] {
        let adjustedCount = TestConfiguration.shared.isCI ? min(count, 50) : count
        return (0..<adjustedCount).map { index in
            ExerciseEntry(
                exerciseName: "Exercise \(index)",
                date: Date().addingTimeInterval(-Double(index) * 3600),
                sets: [ExerciseSet(reps: 10, weight: 50.0)]
            )
        }
    }
    
    // CI-optimized exercise names
    public static func getEnvironmentExerciseNames() -> [String] {
        TestConfiguration.shared.isCI ? ciExerciseNames : fullExerciseNames
    }
}
```

### Common Anti-Patterns to Avoid

#### 1. @testable Import in Cross-Module Tests
```swift
// ❌ DON'T: This breaks release builds
@testable import WorkoutTracker
```

#### 2. Missing Public Initializers
```swift
// ❌ DON'T: Internal initializer prevents test access
internal init(exerciseName: String, date: Date, sets: [ExerciseSet]) { ... }

// ✅ DO: Public initializer enables test data creation
public init(exerciseName: String, date: Date, sets: [ExerciseSet]) { ... }
```

#### 3. Inconsistent Access Levels
```swift
// ❌ DON'T: Mix of public and internal properties
public struct ExerciseEntry {
    public var id = UUID()
    var exerciseName: String      // ❌ Internal property
    public var date: Date
}

// ✅ DO: Consistent public access for test compatibility
public struct ExerciseEntry {
    public var id = UUID()
    public var exerciseName: String
    public var date: Date
}
```

### Quality Gates for Release Build Compatibility

#### Pre-commit Hook Validation
The enhanced pre-commit hook automatically detects and prevents @testable import issues:

1. **Intelligent Detection**: Validates release builds when test modules or Package.swift change
2. **Actionable Guidance**: Provides specific steps to fix @testable import issues
3. **Performance Optimized**: Only runs validation when necessary

#### Manual Release Build Testing
```bash
# Test release build compatibility locally
swift build -c release

# Test release configuration with full test suite
swift test -c release

# Validate specific test module compatibility
swift build -c release && swift test --filter TestConfiguration
```

### Migration from @testable Import

#### Step-by-Step Migration Process

1. **Identify Dependencies**: Find what internal APIs the test module needs
   ```bash
   grep -r "WorkoutTracker\." Tests/TestConfiguration/
   ```

2. **Make Types Public**: Add public access to required types and initializers
   ```swift
   public struct ExerciseEntry: Identifiable, Codable {
       public init(...) { ... }
   }
   ```

3. **Replace @testable Import**: Change to regular import
   ```swift
   - @testable import WorkoutTracker
   + import WorkoutTracker
   ```

4. **Validate Release Build**: Test that release builds work
   ```bash
   swift build -c release && swift test -c release
   ```

#### Verification Checklist

- [ ] All test configuration modules use regular `import` statements
- [ ] Required types have public access modifiers
- [ ] Public initializers are available for test data creation
- [ ] Release builds compile without errors
- [ ] All tests pass in both debug and release configurations
- [ ] Pre-commit hooks validate release build compatibility

### Best Practices Summary

1. **Never use @testable import** in test configuration modules
2. **Design public APIs thoughtfully** for test access
3. **Test both debug and release** configurations regularly
4. **Use environment-aware test data** for CI optimization
5. **Validate changes** with release build testing
6. **Leverage pre-commit hooks** for early detection of issues

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