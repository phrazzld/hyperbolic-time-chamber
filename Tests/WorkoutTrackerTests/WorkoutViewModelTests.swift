import XCTest
import Combine
@testable import WorkoutTracker

/// Comprehensive test suite for WorkoutViewModel add/delete/update operations
final class WorkoutViewModelTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var dataStore: DataStore!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // Create isolated test environment
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Initialize test DataStore and ViewModel
        dataStore = DataStore(baseDirectory: tempDirectory)
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        cancellables.removeAll()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitWithEmptyDataStore() {
        // Test ViewModel initializes with empty entries when DataStore is empty
        XCTAssertTrue(viewModel.entries.isEmpty, "Should start with empty entries")
    }

    func testInitWithExistingData() {
        // Test ViewModel loads existing data from DataStore
        let testEntries = createTestEntries()
        dataStore.save(entries: testEntries)

        // Create new ViewModel instance to test loading
        let newViewModel = WorkoutViewModel(dataStore: dataStore)

        XCTAssertEqual(newViewModel.entries.count, testEntries.count)
        XCTAssertEqual(newViewModel.entries.first?.exerciseName, testEntries.first?.exerciseName)
    }

    // MARK: - Add Entry Tests

    func testAddEntry() {
        // Test adding a single entry updates state and persists
        let initialCount = viewModel.entries.count
        let newEntry = createTestEntry(name: "Test Exercise")

        viewModel.addEntry(newEntry)

        XCTAssertEqual(viewModel.entries.count, initialCount + 1)
        XCTAssertEqual(viewModel.entries.last?.exerciseName, "Test Exercise")

        // Verify persistence by loading from DataStore
        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, initialCount + 1)
        XCTAssertEqual(loadedEntries.last?.exerciseName, "Test Exercise")
    }

    func testAddMultipleEntries() {
        // Test adding multiple entries maintains order and persists all
        let entry1 = createTestEntry(name: "Exercise 1")
        let entry2 = createTestEntry(name: "Exercise 2")
        let entry3 = createTestEntry(name: "Exercise 3")

        viewModel.addEntry(entry1)
        viewModel.addEntry(entry2)
        viewModel.addEntry(entry3)

        XCTAssertEqual(viewModel.entries.count, 3)
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Exercise 1")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Exercise 2")
        XCTAssertEqual(viewModel.entries[2].exerciseName, "Exercise 3")

        // Verify all entries are persisted
        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, 3)
    }

    func testAddEntryTriggersPublishedUpdate() {
        // Test that adding entry triggers @Published updates
        let expectation = XCTestExpectation(description: "Published update")
        var updateCount = 0

        viewModel.$entries
            .dropFirst() // Skip initial value
            .sink { _ in
                updateCount += 1
                if updateCount == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let newEntry = createTestEntry(name: "Published Test")
        viewModel.addEntry(newEntry)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(updateCount, 1, "Should trigger exactly one published update")
    }

    // MARK: - Delete Entry Tests

    func testDeleteEntryAtOffsets() {
        // Test deleting entries at specific offsets
        let entries = createTestEntries()
        entries.forEach { viewModel.addEntry($0) }

        let initialCount = viewModel.entries.count
        XCTAssertGreaterThan(initialCount, 1, "Need multiple entries for deletion test")

        // Delete first entry
        let indexSet = IndexSet(integer: 0)
        let deletedEntryName = viewModel.entries[0].exerciseName

        viewModel.deleteEntry(at: indexSet)

        XCTAssertEqual(viewModel.entries.count, initialCount - 1)
        XCTAssertNotEqual(viewModel.entries.first?.exerciseName, deletedEntryName)

        // Verify persistence
        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, initialCount - 1)
    }

    func testDeleteMultipleEntries() {
        // Test deleting multiple entries at once
        let entries = createTestEntries()
        entries.forEach { viewModel.addEntry($0) }

        let initialCount = viewModel.entries.count
        XCTAssertGreaterThanOrEqual(initialCount, 2, "Need at least 2 entries")

        // Delete first two entries
        let indexSet = IndexSet([0, 1])
        viewModel.deleteEntry(at: indexSet)

        XCTAssertEqual(viewModel.entries.count, initialCount - 2)

        // Verify persistence
        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, initialCount - 2)
    }

    func testDeleteAllEntries() {
        // Test deleting all entries results in empty state
        let entries = createTestEntries()
        entries.forEach { viewModel.addEntry($0) }

        let allIndices = IndexSet(integersIn: 0..<viewModel.entries.count)
        viewModel.deleteEntry(at: allIndices)

        XCTAssertTrue(viewModel.entries.isEmpty)

        // Verify persistence
        let loadedEntries = dataStore.load()
        XCTAssertTrue(loadedEntries.isEmpty)
    }

    func testDeleteEntryTriggersPublishedUpdate() {
        // Test that deleting entry triggers @Published updates
        let entry = createTestEntry(name: "To Delete")
        viewModel.addEntry(entry)

        let expectation = XCTestExpectation(description: "Delete published update")
        var deleteUpdateReceived = false

        viewModel.$entries
            .dropFirst() // Skip initial value
            .sink { entries in
                // Only fulfill when we see the delete (empty array)
                if entries.isEmpty && !deleteUpdateReceived {
                    deleteUpdateReceived = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let indexSet = IndexSet(integer: 0)
        viewModel.deleteEntry(at: indexSet)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(deleteUpdateReceived, "Should trigger published update for delete")
        XCTAssertTrue(viewModel.entries.isEmpty, "Entries should be empty after delete")
    }

    // MARK: - Save Operation Tests

    func testManualSave() {
        // Test manual save operation persists current state
        let entries = createTestEntries()

        // Add entries without triggering automatic save
        viewModel.entries.append(contentsOf: entries)

        // Verify not yet persisted
        let loadedBefore = dataStore.load()
        XCTAssertNotEqual(loadedBefore.count, entries.count)

        // Manual save
        viewModel.save()

        // Verify now persisted
        let loadedAfter = dataStore.load()
        XCTAssertEqual(loadedAfter.count, entries.count)
    }

    // MARK: - Export Operation Tests

    func testExportJSON() {
        // Test exporting entries to JSON file
        let entries = createTestEntries()
        entries.forEach { viewModel.addEntry($0) }

        let exportURL = viewModel.exportJSON()

        XCTAssertNotNil(exportURL, "Export should return valid URL")

        guard let exportURL = exportURL else {
            XCTFail("Export URL is nil")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify exported content is valid JSON
        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData)

        XCTAssertNotNil(exportedEntries)
        XCTAssertEqual(exportedEntries?.count, entries.count)
    }

    func testExportEmptyEntries() {
        // Test exporting when no entries exist
        XCTAssertTrue(viewModel.entries.isEmpty)

        let exportURL = viewModel.exportJSON()
        XCTAssertNotNil(exportURL, "Should be able to export empty entries")

        guard let exportURL = exportURL else { return }

        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData)
        XCTAssertNotNil(exportedEntries)
        XCTAssertTrue(exportedEntries?.isEmpty == true)
    }

    // MARK: - State Consistency Tests

    func testStateConsistencyAfterOperations() {
        // Test that ViewModel state remains consistent after multiple operations
        let entry1 = createTestEntry(name: "Entry 1")
        let entry2 = createTestEntry(name: "Entry 2")
        let entry3 = createTestEntry(name: "Entry 3")

        // Add entries
        viewModel.addEntry(entry1)
        viewModel.addEntry(entry2)
        viewModel.addEntry(entry3)
        XCTAssertEqual(viewModel.entries.count, 3)

        // Delete middle entry
        viewModel.deleteEntry(at: IndexSet(integer: 1))
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Entry 1")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Entry 3")

        // Add another entry
        let entry4 = createTestEntry(name: "Entry 4")
        viewModel.addEntry(entry4)
        XCTAssertEqual(viewModel.entries.count, 3)

        // Verify persistence matches state
        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, viewModel.entries.count)

        for (viewModelEntry, loadedEntry) in zip(viewModel.entries, loadedEntries) {
            XCTAssertEqual(viewModelEntry.exerciseName, loadedEntry.exerciseName)
            XCTAssertEqual(viewModelEntry.sets.count, loadedEntry.sets.count)
        }
    }

    // MARK: - Helper Methods

    private func createTestEntry(name: String) -> ExerciseEntry {
        let sets = [
            ExerciseSet(reps: 10, weight: 50.0),
            ExerciseSet(reps: 8, weight: 55.0)
        ]
        return ExerciseEntry(exerciseName: name, date: Date(), sets: sets)
    }

    private func createTestEntries() -> [ExerciseEntry] {
        [
            createTestEntry(name: "Bench Press"),
            createTestEntry(name: "Squats"),
            createTestEntry(name: "Deadlifts")
        ]
    }
}
