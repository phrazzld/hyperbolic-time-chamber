# Development Guide

This guide provides comprehensive information for developers working on the WorkoutTracker iOS application, with a focus on dependency injection patterns and best practices.

## Table of Contents

- [Dependency Injection Architecture](#dependency-injection-architecture)
- [Core Components](#core-components)
- [Testing Patterns](#testing-patterns)
- [Best Practices](#best-practices)
- [Adding New Dependencies](#adding-new-dependencies)

## Dependency Injection Architecture

### Overview

WorkoutTracker uses a protocol-based dependency injection architecture to achieve clean separation of concerns, testability, and environment-aware behavior. This design enables different data storage implementations for production, testing, and demo scenarios without changing business logic.

### Why Dependency Injection?

**Benefits achieved:**
- **Testability**: Fast, isolated unit tests using in-memory implementations
- **Environment Awareness**: Different behaviors for production, testing, and screenshots
- **Flexibility**: Easy to add new storage backends (CloudKit, Core Data, etc.)
- **Security**: Graceful fallbacks when storage initialization fails
- **Performance**: 50%+ faster test execution by eliminating file I/O

**Key Principle**: The application depends on abstractions (protocols), not concrete implementations.

## Core Components

### 1. DataStoreProtocol

The central abstraction for data persistence operations.

```swift
public protocol DataStoreProtocol {
    /// Loads saved entries from storage
    func load(correlationId: String?) throws -> [ExerciseEntry]
    
    /// Saves entries to storage
    func save(entries: [ExerciseEntry], correlationId: String?) throws
    
    /// Exports entries to a shareable format and returns its URL
    func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL
}
```

**Protocol Extensions** provide convenience methods with auto-generated correlation IDs:

```swift
// These methods automatically generate correlation IDs for observability
dataStore.load()  // Calls load(correlationId: UUID().uuidString)
dataStore.save(entries: entries)  // Auto-generates correlation ID
dataStore.export(entries: entries)  // Auto-generates correlation ID
```

### 2. Implementations

#### FileDataStore (Production)
- Persists data to local Documents directory as JSON
- Security hardened against path traversal attacks
- Comprehensive structured logging with correlation IDs
- Graceful error handling for file system issues

```swift
let fileStore = try FileDataStore(
    fileManager: .default,
    baseDirectory: nil,  // Uses Documents directory
    fileName: "workout_entries.json"
)
```

#### InMemoryDataStore (Testing/Demo)
- Stores data in memory for fast, isolated tests
- Can be pre-loaded with test data
- No file system dependencies
- Perfect for unit tests and UI testing

```swift
let testData = [
    ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
]
let memoryStore = InMemoryDataStore(entries: testData)
```

### 3. DependencyFactory

Central factory for creating properly configured dependencies based on environment.

```swift
public struct DependencyFactory {
    /// Configuration for dependency creation
    public struct Configuration {
        public let isDemo: Bool
        public let isScreenshotMode: Bool
        public let isUITesting: Bool
        public let fileManager: FileManager
        public let baseDirectory: URL?
    }
    
    /// Creates environment-appropriate DataStore
    public static func createDataStore(configuration: Configuration) throws -> DataStoreProtocol
    
    /// Creates ViewModel with appropriate DataStore
    public static func createViewModel(configuration: Configuration = .fromEnvironment) throws -> WorkoutViewModel
}
```

**Environment Detection Logic:**
- **Production**: Uses FileDataStore for persistent storage
- **Demo/Screenshots**: Uses InMemoryDataStore with demo data
- **UI Testing**: Uses InMemoryDataStore for isolated tests

### 4. WorkoutViewModel

The main business logic component that depends on DataStoreProtocol.

```swift
public class WorkoutViewModel: ObservableObject {
    @Published public var entries: [ExerciseEntry] = []
    private let dataStore: DataStoreProtocol
    
    public init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
        // Load initial data
        do {
            entries = try dataStore.load()
        } catch {
            // Handle errors gracefully
            NSLog("Failed to load entries: \(error)")
            entries = []
        }
    }
}
```

## Testing Patterns

### Unit Testing with InMemoryDataStore

**Fast, isolated unit tests** that don't touch the file system:

```swift
final class WorkoutViewModelTests: XCTestCase {
    var viewModel: WorkoutViewModel!
    var dataStore: DataStoreProtocol!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for fast, isolated tests
        dataStore = InMemoryDataStore()
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }
    
    func testAddEntry() {
        let entry = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
        
        viewModel.addEntry(entry)
        
        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.exerciseName, "Test")
    }
}
```

### Testing with Pre-loaded Data

**Pre-populate test data** for specific test scenarios:

```swift
func testViewModelWithExistingData() {
    // Arrange: Create pre-loaded data store
    let testEntries = [
        ExerciseEntry(exerciseName: "Bench Press", date: Date(), sets: []),
        ExerciseEntry(exerciseName: "Squats", date: Date(), sets: [])
    ]
    let dataStore = InMemoryDataStore(entries: testEntries)
    
    // Act: Create ViewModel with pre-loaded data
    let viewModel = WorkoutViewModel(dataStore: dataStore)
    
    // Assert: ViewModel has the expected data
    XCTAssertEqual(viewModel.entries.count, 2)
    XCTAssertEqual(viewModel.entries[0].exerciseName, "Bench Press")
}
```

### Testing DependencyFactory

**Verify environment-aware dependency creation:**

```swift
func testDependencyFactoryEnvironmentDetection() {
    // Test production configuration
    let prodConfig = DependencyFactory.Configuration(
        isDemo: false,
        isScreenshotMode: false,
        isUITesting: false
    )
    let prodStore = try! DependencyFactory.createDataStore(configuration: prodConfig)
    XCTAssertTrue(prodStore is FileDataStore)
    
    // Test demo configuration  
    let demoConfig = DependencyFactory.Configuration(
        isDemo: true,
        isScreenshotMode: false,
        isUITesting: false
    )
    let demoStore = try! DependencyFactory.createDataStore(configuration: demoConfig)
    XCTAssertTrue(demoStore is InMemoryDataStore)
}
```

### Custom Mock DataStores

**Create custom mocks for specific test scenarios:**

```swift
class MockDataStore: DataStoreProtocol {
    var loadCallCount = 0
    var saveCallCount = 0
    var savedEntries: [ExerciseEntry] = []
    
    func load(correlationId: String?) throws -> [ExerciseEntry] {
        loadCallCount += 1
        return []
    }
    
    func save(entries: [ExerciseEntry], correlationId: String?) throws {
        saveCallCount += 1
        savedEntries = entries
    }
    
    func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL {
        return URL(string: "mock://export")!
    }
}

func testViewModelCallsDataStore() {
    let mockStore = MockDataStore()
    let viewModel = WorkoutViewModel(dataStore: mockStore)
    
    // Verify initialization triggered load
    XCTAssertEqual(mockStore.loadCallCount, 1)
    
    // Test that adding entry triggers save
    viewModel.addEntry(testEntry)
    XCTAssertEqual(mockStore.saveCallCount, 1)
    XCTAssertEqual(mockStore.savedEntries.count, 1)
}
```

## Best Practices

### 1. Never Mock Internal Collaborators

❌ **Don't do this:**
```swift
// Mocking internal domain objects breaks encapsulation
let mockEntry = MockExerciseEntry()
```

✅ **Do this instead:**
```swift
// Use real domain objects, mock external dependencies only
let realEntry = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
let mockDataStore = InMemoryDataStore(entries: [realEntry])
```

### 2. Use Protocol Extensions for Convenience

The protocol provides both explicit and convenience methods:

```swift
// Explicit correlation ID (for request tracing)
try dataStore.save(entries: entries, correlationId: "user-action-123")

// Auto-generated correlation ID (for most cases)
try dataStore.save(entries: entries)
```

### 3. Graceful Error Handling

Always handle potential DataStore failures gracefully:

```swift
init() {
    let workoutViewModel: WorkoutViewModel
    do {
        workoutViewModel = try DependencyFactory.createViewModel()
    } catch {
        // Fallback to safe in-memory store
        NSLog("Failed to create file store, using in-memory: \(error)")
        workoutViewModel = DependencyFactory.createViewModel(dataStore: InMemoryDataStore())
    }
    _viewModel = StateObject(wrappedValue: workoutViewModel)
}
```

### 4. Environment-Aware Configuration

Use the factory's automatic environment detection:

```swift
// Automatically detects environment and creates appropriate DataStore
let viewModel = try DependencyFactory.createViewModel()

// Or explicitly specify for testing
let testConfig = DependencyFactory.Configuration(isUITesting: true)
let viewModel = try DependencyFactory.createViewModel(configuration: testConfig)
```

## Adding New Dependencies

### Step 1: Define the Protocol

Create a protocol for the new dependency:

```swift
public protocol NetworkServiceProtocol {
    func fetchData() async throws -> Data
    func uploadData(_ data: Data) async throws
}
```

### Step 2: Create Implementations

Implement both production and test versions:

```swift
// Production implementation
public class HTTPNetworkService: NetworkServiceProtocol {
    public func fetchData() async throws -> Data {
        // Real network implementation
    }
    
    public func uploadData(_ data: Data) async throws {
        // Real upload implementation
    }
}

// Test implementation  
public class MockNetworkService: NetworkServiceProtocol {
    public var mockData: Data = Data()
    public var shouldThrowError = false
    
    public func fetchData() async throws -> Data {
        if shouldThrowError { throw NetworkError.connectionFailed }
        return mockData
    }
    
    public func uploadData(_ data: Data) async throws {
        if shouldThrowError { throw NetworkError.uploadFailed }
        // Mock upload success
    }
}
```

### Step 3: Update DependencyFactory

Add factory methods for the new dependency:

```swift
extension DependencyFactory {
    /// Creates network service based on configuration
    public static func createNetworkService(configuration: Configuration) -> NetworkServiceProtocol {
        if configuration.isUITesting || configuration.isDemo {
            return MockNetworkService()
        }
        return HTTPNetworkService()
    }
    
    /// Creates ViewModel with all dependencies
    public static func createViewModel(configuration: Configuration = .fromEnvironment) throws -> WorkoutViewModel {
        let dataStore = try createDataStore(configuration: configuration)
        let networkService = createNetworkService(configuration: configuration)
        return WorkoutViewModel(dataStore: dataStore, networkService: networkService)
    }
}
```

### Step 4: Update Consumer Classes

Inject the new dependency:

```swift
public class WorkoutViewModel: ObservableObject {
    @Published public var entries: [ExerciseEntry] = []
    private let dataStore: DataStoreProtocol
    private let networkService: NetworkServiceProtocol  // New dependency
    
    public init(dataStore: DataStoreProtocol, networkService: NetworkServiceProtocol) {
        self.dataStore = dataStore
        self.networkService = networkService
        // Initialize as before...
    }
}
```

### Step 5: Update Tests

Use the new test implementation in tests:

```swift
func testNetworkDataSync() {
    let mockNetwork = MockNetworkService()
    mockNetwork.mockData = testJSONData
    
    let dataStore = InMemoryDataStore()
    let viewModel = WorkoutViewModel(dataStore: dataStore, networkService: mockNetwork)
    
    // Test network-dependent functionality
}
```

## Architecture Benefits

This dependency injection architecture provides:

1. **Clean Architecture**: Business logic is independent of infrastructure concerns
2. **Fast Testing**: Unit tests run 50%+ faster without file I/O
3. **Environment Flexibility**: Different behaviors for production, testing, and demos
4. **Security**: Graceful fallbacks when storage initialization fails
5. **Observability**: Correlation IDs enable request tracing across operations
6. **Extensibility**: Easy to add new storage backends or services

The pattern follows SOLID principles and enables confident refactoring while maintaining comprehensive test coverage.