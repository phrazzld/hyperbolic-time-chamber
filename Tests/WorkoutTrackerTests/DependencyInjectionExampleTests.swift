import XCTest
@testable import WorkoutTracker

/// Example tests demonstrating proper dependency injection patterns
final class DependencyInjectionExampleTests: XCTestCase {

    // MARK: - Using InMemoryDataStore

    func testViewModelWithInMemoryStore() {
        // Arrange: Create in-memory store with pre-populated data
        let testData = [
            ExerciseEntry(
                exerciseName: "Test Exercise",
                date: Date(),
                sets: [ExerciseSet(reps: 10, weight: 50.0)]
            )
        ]
        let dataStore = InMemoryDataStore(entries: testData)

        // Act: Create view model with injected store
        let viewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: View model loads the pre-populated data
        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.exerciseName, "Test Exercise")
    }

    // MARK: - Using DependencyFactory

    func testDependencyFactoryCreatesCorrectDataStore() {
        // Test production configuration
        let prodConfig = DependencyFactory.Configuration(
            isDemo: false,
            isScreenshotMode: false,
            isUITesting: false
        )
        let prodStore = DependencyFactory.createDataStore(configuration: prodConfig)
        XCTAssertTrue(prodStore is DataStore, "Production should use DataStore")

        // Test demo configuration
        let demoConfig = DependencyFactory.Configuration(
            isDemo: true,
            isScreenshotMode: false,
            isUITesting: false
        )
        let demoStore = DependencyFactory.createDataStore(configuration: demoConfig)
        XCTAssertTrue(demoStore is InMemoryDataStore, "Demo mode should use InMemoryDataStore")

        // Test UI testing configuration
        let testConfig = DependencyFactory.Configuration(
            isDemo: false,
            isScreenshotMode: false,
            isUITesting: true
        )
        let testStore = DependencyFactory.createDataStore(configuration: testConfig)
        XCTAssertTrue(testStore is InMemoryDataStore, "UI testing should use InMemoryDataStore")
    }

    func testDependencyFactoryCreatesViewModelWithCorrectStore() {
        // Test creating view model with custom configuration
        let config = DependencyFactory.Configuration(
            isDemo: true,
            isScreenshotMode: false,
            isUITesting: false
        )
        let viewModel = DependencyFactory.createViewModel(configuration: config)

        // The view model should be properly initialized
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel.entries.isEmpty, "New view model should start empty")

        // Add an entry and verify it's stored (but not persisted to disk in demo mode)
        let testEntry = ExerciseEntry(
            exerciseName: "Demo Exercise",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: 50.0)]
        )
        viewModel.addEntry(testEntry)
        XCTAssertEqual(viewModel.entries.count, 1)
    }

    // MARK: - Custom Mock DataStore

    func testViewModelWithCustomMockStore() {
        // Create a custom mock that tracks method calls
        class MockDataStore: DataStoreProtocol {
            var loadCallCount = 0
            var saveCallCount = 0
            var exportCallCount = 0
            var savedEntries: [ExerciseEntry] = []

            func load() -> [ExerciseEntry] {
                loadCallCount += 1
                return []
            }

            func save(entries: [ExerciseEntry]) {
                saveCallCount += 1
                savedEntries = entries
            }

            func export(entries: [ExerciseEntry]) -> URL? {
                exportCallCount += 1
                return URL(string: "mock://export")
            }
        }

        // Use the mock in tests
        let mockStore = MockDataStore()
        let viewModel = WorkoutViewModel(dataStore: mockStore)

        // Verify load was called during initialization
        XCTAssertEqual(mockStore.loadCallCount, 1)

        // Add an entry and verify save was called
        let entry = ExerciseEntry(
            exerciseName: "Test",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: 50.0)]
        )
        viewModel.addEntry(entry)

        XCTAssertEqual(mockStore.saveCallCount, 1)
        XCTAssertEqual(mockStore.savedEntries.count, 1)
        XCTAssertEqual(mockStore.savedEntries.first?.exerciseName, "Test")

        // Export and verify export was called
        let exportURL = viewModel.exportJSON()
        XCTAssertNotNil(exportURL)
        XCTAssertEqual(mockStore.exportCallCount, 1)
    }

    // MARK: - Testing with File-Based DataStore

    func testViewModelWithFileBasedStore() {
        // Create temporary directory for test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DependencyInjectionTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up after test
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create file-based store with custom directory
        let fileStore = FileDataStore(baseDirectory: tempDir)
        let viewModel = WorkoutViewModel(dataStore: fileStore)

        // Add entry and verify it persists
        let entry = ExerciseEntry(
            exerciseName: "Persistent Test",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: 50.0)]
        )
        viewModel.addEntry(entry)

        // Create new view model with same store to verify persistence
        let newViewModel = WorkoutViewModel(dataStore: fileStore)
        XCTAssertEqual(newViewModel.entries.count, 1)
        XCTAssertEqual(newViewModel.entries.first?.exerciseName, "Persistent Test")
    }
}
