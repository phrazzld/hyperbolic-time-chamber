import XCTest
@testable import WorkoutTracker

final class WorkoutViewModelErrorTests: XCTestCase {

    func testInitializationWithFailingDataStore() {
        // Create a mock data store that throws on load
        let failingDataStore = FailingMockDataStore()

        // ViewModel should handle the load failure gracefully and start with empty entries
        let viewModel = WorkoutViewModel(dataStore: failingDataStore)

        XCTAssertEqual(viewModel.entries.count, 0, "ViewModel should start with empty entries when load fails")
        XCTAssertEqual(failingDataStore.loadCallCount, 1, "Load should have been called once during initialization")
    }

    func testSaveWithFailingDataStore() {
        // Create a mock data store that throws on save
        let failingDataStore = FailingMockDataStore()
        failingDataStore.shouldFailLoad = false  // Allow successful initialization
        failingDataStore.shouldFailSave = true   // But fail on save

        let viewModel = WorkoutViewModel(dataStore: failingDataStore)
        let testEntry = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])

        // Add entry should handle save failure gracefully
        viewModel.addEntry(testEntry)

        XCTAssertEqual(viewModel.entries.count, 1, "Entry should be added to in-memory collection even if save fails")
        XCTAssertEqual(failingDataStore.saveCallCount, 1, "Save should have been attempted")
    }

    func testExportJSONWithFailingDataStore() {
        // Create a mock data store that throws on export
        let failingDataStore = FailingMockDataStore()
        failingDataStore.shouldFailLoad = false    // Allow successful initialization
        failingDataStore.shouldFailExport = true   // But fail on export

        let viewModel = WorkoutViewModel(dataStore: failingDataStore)

        // Export should handle failure gracefully and return nil
        let exportURL = viewModel.exportJSON()

        XCTAssertNil(exportURL, "Export should return nil when DataStore export fails")
        XCTAssertEqual(failingDataStore.exportCallCount, 1, "Export should have been attempted")
    }

    func testManualSaveWithFailingDataStore() {
        // Create a mock data store that throws on save
        let failingDataStore = FailingMockDataStore()
        failingDataStore.shouldFailLoad = false  // Allow successful initialization
        failingDataStore.shouldFailSave = true   // But fail on save

        let viewModel = WorkoutViewModel(dataStore: failingDataStore)

        // Manual save should handle failure gracefully
        viewModel.save()

        XCTAssertEqual(failingDataStore.saveCallCount, 1, "Save should have been attempted")
        // No crash should occur
    }
}

// MARK: - Mock Data Store for Testing Error Scenarios

private class FailingMockDataStore: DataStoreProtocol {
    var shouldFailLoad = true
    var shouldFailSave = false
    var shouldFailExport = false

    var loadCallCount = 0
    var saveCallCount = 0
    var exportCallCount = 0

    func load(correlationId: String?) throws -> [ExerciseEntry] {
        loadCallCount += 1
        if shouldFailLoad {
            throw DataStoreError.loadFailed(underlyingError: MockError.loadFailed)
        }
        return []
    }

    func save(entries: [ExerciseEntry], correlationId: String?) throws {
        saveCallCount += 1
        if shouldFailSave {
            throw DataStoreError.saveFailed(underlyingError: MockError.saveFailed)
        }
    }

    func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL {
        exportCallCount += 1
        if shouldFailExport {
            throw DataStoreError.exportFailed(reason: "Mock export failure")
        }
        return URL(string: "mock://export") ?? URL(fileURLWithPath: "/tmp/mock")
    }
}

private enum MockError: Error {
    case loadFailed
    case saveFailed
}
