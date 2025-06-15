import XCTest
import Foundation
import Combine
@testable import WorkoutTracker

/// Comprehensive tests for the "View and delete workout from history" complete user flow
/// Tests all scenarios for viewing workout history and deleting entries to ensure robust functionality
final class HistoryDeleteFlowTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var testDataStore: DataStore!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        // Create isolated temp directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory,
                                                withIntermediateDirectories: true)

        // Create isolated DataStore for testing
        testDataStore = DataStore(baseDirectory: tempDirectory)

        // Create ViewModel with test DataStore
        viewModel = WorkoutViewModel(dataStore: testDataStore)
    }

    override func tearDownWithError() throws {
        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        viewModel = nil
        testDataStore = nil
        tempDirectory = nil
    }

    // MARK: - History Viewing Tests

    func testViewEmptyHistory() throws {
        // Test viewing history when no workout entries exist
        XCTAssertTrue(viewModel.entries.isEmpty, "History should be empty initially")

        // Verify the UI state reflects empty history
        XCTAssertEqual(viewModel.entries.count, 0)

        // Verify persistence maintains empty state
        let newViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertTrue(newViewModel.entries.isEmpty, "Empty history should persist")
    }

    func testViewPopulatedHistory() throws {
        // Setup: Add sample workout entries to create history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }

        // Verify history shows all entries
        XCTAssertEqual(viewModel.entries.count, 3, "History should show all added entries")

        // Verify entries are accessible for viewing
        let entries = viewModel.entries
        XCTAssertEqual(entries[0].exerciseName, "Monday Workout")
        XCTAssertEqual(entries[1].exerciseName, "Wednesday Workout")
        XCTAssertEqual(entries[2].exerciseName, "Friday Workout")

        // Verify each entry has expected data
        for entry in entries {
            XCTAssertFalse(entry.sets.isEmpty, "Each entry should have sets")
            XCTAssertFalse(entry.exerciseName.isEmpty, "Each entry should have an exercise name")
        }

        // Verify history persists correctly
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 3, "History should persist across sessions")
    }

    // MARK: - Single Entry Deletion Tests

    func testDeleteSingleEntryFromHistory() throws {
        // Setup: Create workout history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 3)

        // Delete the middle entry (index 1)
        let initialSecondEntryName = viewModel.entries[1].exerciseName
        let indexToDelete = IndexSet([1])
        viewModel.deleteEntry(at: indexToDelete)

        // Verify deletion succeeded
        XCTAssertEqual(viewModel.entries.count, 2, "Should have 2 entries after deleting 1")

        // Verify the correct entry was deleted
        let remainingNames = viewModel.entries.map { $0.exerciseName }
        XCTAssertFalse(remainingNames.contains(initialSecondEntryName), "Deleted entry should not be present")
        XCTAssertTrue(remainingNames.contains("Monday Workout"), "First entry should remain")
        XCTAssertTrue(remainingNames.contains("Friday Workout"), "Third entry should remain")

        // Verify order is maintained for remaining entries
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Monday Workout")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Friday Workout")
        // Verify deletion persists
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 2, "Deletion should persist")
        let persistedNames = persistedViewModel.entries.map { $0.exerciseName }
        XCTAssertFalse(persistedNames.contains(initialSecondEntryName), "Deleted entry should not persist")
    }

    func testDeleteFirstEntryFromHistory() throws {
        // Setup: Create workout history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }

        // Delete the first entry
        let firstEntryName = viewModel.entries[0].exerciseName
        viewModel.deleteEntry(at: IndexSet([0]))

        // Verify deletion and reordering
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertNotEqual(viewModel.entries[0].exerciseName, firstEntryName)
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Wednesday Workout")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Friday Workout")
    }

    func testDeleteLastEntryFromHistory() throws {
        // Setup: Create workout history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }

        // Delete the last entry
        let lastIndex = viewModel.entries.count - 1
        let lastEntryName = viewModel.entries[lastIndex].exerciseName
        viewModel.deleteEntry(at: IndexSet([lastIndex]))

        // Verify deletion
        XCTAssertEqual(viewModel.entries.count, 2)
        let remainingNames = viewModel.entries.map { $0.exerciseName }
        XCTAssertFalse(remainingNames.contains(lastEntryName))
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Monday Workout")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Wednesday Workout")
    }

    // MARK: - Multiple Entry Deletion Tests

    func testDeleteMultipleEntriesSimultaneously() throws {
        // Setup: Create a larger history for multiple deletions
        let entries = createLargerWorkoutHistory()
        for entry in entries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 5)

        // Delete multiple non-contiguous entries (indices 1 and 3)
        let indicesToDelete = IndexSet([1, 3])
        let deletedNames = [viewModel.entries[1].exerciseName, viewModel.entries[3].exerciseName]
        viewModel.deleteEntry(at: indicesToDelete)

        // Verify multiple deletions
        XCTAssertEqual(viewModel.entries.count, 3, "Should have 3 entries after deleting 2")

        // Verify correct entries were deleted
        let remainingNames = viewModel.entries.map { $0.exerciseName }
        for deletedName in deletedNames {
            XCTAssertFalse(remainingNames.contains(deletedName), "\(deletedName) should be deleted")
        }

        // Verify remaining entries maintain relative order
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Workout A")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Workout C")
        XCTAssertEqual(viewModel.entries[2].exerciseName, "Workout E")
    }

    func testDeleteContiguousMultipleEntries() throws {
        // Setup: Create workout history
        let entries = createLargerWorkoutHistory()
        for entry in entries {
            viewModel.addEntry(entry)
        }

        // Delete contiguous entries (indices 1, 2, 3)
        let indicesToDelete = IndexSet([1, 2, 3])
        viewModel.deleteEntry(at: indicesToDelete)

        // Verify contiguous deletion
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Workout A")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Workout E")

        // Verify persistence
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 2)
    }

    // MARK: - Complete History Deletion Tests

    func testDeleteAllEntriesFromHistory() throws {
        // Setup: Create workout history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 3)

        // Delete all entries one by one
        while !viewModel.entries.isEmpty {
            viewModel.deleteEntry(at: IndexSet([0]))
        }

        // Verify complete deletion
        XCTAssertTrue(viewModel.entries.isEmpty, "All entries should be deleted")

        // Verify empty state persists
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertTrue(persistedViewModel.entries.isEmpty, "Empty state should persist")
    }

    func testDeleteAllEntriesAtOnce() throws {
        // Setup: Create workout history
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }

        // Delete all entries simultaneously
        let allIndices = IndexSet(0..<viewModel.entries.count)
        viewModel.deleteEntry(at: allIndices)

        // Verify complete deletion
        XCTAssertTrue(viewModel.entries.isEmpty, "All entries should be deleted at once")

        // Verify persistence
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertTrue(persistedViewModel.entries.isEmpty, "Complete deletion should persist")
    }

    // MARK: - State Management During Deletion

    func testStateManagementDuringDeletion() throws {
        // Setup: Create workout history and monitor state changes
        let sampleEntries = createSampleWorkoutEntries()
        for entry in sampleEntries {
            viewModel.addEntry(entry)
        }

        var entryCountUpdates: [Int] = []
        let cancellable = viewModel.$entries
            .map { $0.count }
            .sink { count in
                entryCountUpdates.append(count)
            }

        let initialCount = entryCountUpdates.last ?? 0
        XCTAssertEqual(initialCount, 3, "Should start with 3 entries")

        // Delete entry and verify state update
        viewModel.deleteEntry(at: IndexSet([1]))
        XCTAssertEqual(entryCountUpdates.last, 2, "Count should update to 2 after deletion")

        // Delete another entry
        viewModel.deleteEntry(at: IndexSet([0]))
        XCTAssertEqual(entryCountUpdates.last, 1, "Count should update to 1 after second deletion")

        // Clean up
        cancellable.cancel()

        // Verify state transitions were captured
        XCTAssertTrue(entryCountUpdates.contains(3), "Should contain initial count")
        XCTAssertTrue(entryCountUpdates.contains(2), "Should contain intermediate count")
        XCTAssertTrue(entryCountUpdates.contains(1), "Should contain final count")
    }

    // MARK: - Edge Cases and Error Conditions

    func testDeleteFromEmptyHistory() throws {
        // Verify deletion from empty history doesn't crash
        XCTAssertTrue(viewModel.entries.isEmpty)

        // Attempting to delete from empty collection should be handled gracefully
        let emptyIndexSet = IndexSet()
        viewModel.deleteEntry(at: emptyIndexSet)

        // State should remain empty
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    func testDeleteWithSpecialCharacterEntries() throws {
        // Setup: Create entries with special characters
        let specialEntries = [
            ExerciseEntry(exerciseName: "🏋️‍♂️ Heavy Lifting", date: Date(), sets: [
                ExerciseSet(reps: 5, weight: 100.0, notes: "💪 Strong!")
            ]),
            ExerciseEntry(exerciseName: "Кардио тренировка", date: Date(), sets: [
                ExerciseSet(reps: 30, weight: nil, notes: "Хорошая тренировка")
            ]),
            ExerciseEntry(exerciseName: "\"Quoted\" Exercise Name", date: Date(), sets: [
                ExerciseSet(reps: 10, weight: 50.0, notes: "Test with quotes")
            ])
        ]

        for entry in specialEntries {
            viewModel.addEntry(entry)
        }

        // Delete entry with emoji
        guard let emojiEntryIndex = viewModel.entries.firstIndex(where: { $0.exerciseName.contains("🏋️‍♂️") }) else {
            XCTFail("Should find emoji entry")
            return
        }
        viewModel.deleteEntry(at: IndexSet([emojiEntryIndex]))

        // Verify deletion worked with special characters
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertFalse(viewModel.entries.contains { $0.exerciseName.contains("🏋️‍♂️") })

        // Verify remaining entries with special characters persist
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 2)
        XCTAssertTrue(persistedViewModel.entries.contains { $0.exerciseName == "Кардио тренировка" })
        XCTAssertTrue(persistedViewModel.entries.contains { $0.exerciseName == "\"Quoted\" Exercise Name" })
    }

    func testDeleteAndViewWorkflowSequence() throws {
        // Test complete user workflow: view -> delete -> view -> delete
        let entries = createLargerWorkoutHistory()
        for entry in entries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 5)

        // Delete some entries and verify updated history
        viewModel.deleteEntry(at: IndexSet([0, 2]))
        XCTAssertEqual(viewModel.entries.count, 3)
        let updatedNames = viewModel.entries.map { $0.exerciseName }
        XCTAssertFalse(updatedNames.contains("Workout A"))
        XCTAssertFalse(updatedNames.contains("Workout C"))

        // Delete more entries and verify final state
        viewModel.deleteEntry(at: IndexSet([1]))
        XCTAssertEqual(viewModel.entries.count, 2)

        // Verify persistence of entire workflow
        let finalViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(finalViewModel.entries.count, 2)
    }

    // MARK: - Helper Methods

    private func createSampleWorkoutEntries() -> [ExerciseEntry] {
        let baseDate = Date()
        guard let mondayDate = Calendar.current.date(byAdding: .day, value: -6, to: baseDate),
              let wednesdayDate = Calendar.current.date(byAdding: .day, value: -4, to: baseDate),
              let fridayDate = Calendar.current.date(byAdding: .day, value: -2, to: baseDate) else {
            return []
        }

        return [
            ExerciseEntry(exerciseName: "Monday Workout", date: mondayDate, sets: [
                ExerciseSet(reps: 10, weight: 50.0, notes: "Good start"),
                ExerciseSet(reps: 8, weight: 55.0, notes: "Feeling strong")
            ]),
            ExerciseEntry(exerciseName: "Wednesday Workout", date: wednesdayDate, sets: [
                ExerciseSet(reps: 12, weight: 45.0, notes: "Recovery day"),
                ExerciseSet(reps: 10, weight: 50.0, notes: "Light weight")
            ]),
            ExerciseEntry(exerciseName: "Friday Workout", date: fridayDate, sets: [
                ExerciseSet(reps: 6, weight: 65.0, notes: "Heavy day"),
                ExerciseSet(reps: 4, weight: 70.0, notes: "Max effort")
            ])
        ]
    }

    private func createLargerWorkoutHistory() -> [ExerciseEntry] {
        let baseDate = Date()
        var entries: [ExerciseEntry] = []

        for index in 0..<5 {
            guard let entryDate = Calendar.current.date(byAdding: .day, value: -index, to: baseDate),
                  let unicodeScalar = UnicodeScalar(65 + index) else {
                continue
            }

            let entry = ExerciseEntry(
                exerciseName: "Workout \(Character(unicodeScalar))",
                date: entryDate,
                sets: [ExerciseSet(reps: 10 + index, weight: Double(50 + index * 5), notes: "Set \(index + 1)")]
            )
            entries.append(entry)
        }

        return entries
    }
}
