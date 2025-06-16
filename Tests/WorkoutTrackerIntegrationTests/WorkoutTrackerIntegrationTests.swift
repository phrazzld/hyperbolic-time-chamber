import XCTest
import Foundation
@testable import WorkoutTracker

/// Integration tests for WorkoutTracker critical user flows
/// These tests verify complete workflows end-to-end using the actual app components
final class WorkoutTrackerIntegrationTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var testDataStore: FileDataStore!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        // Create isolated temp directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory,
                                                withIntermediateDirectories: true)

        // Create isolated DataStore for testing
        testDataStore = FileDataStore(baseDirectory: tempDirectory)

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

    // MARK: - Complete User Flow Integration Tests

    func testCompleteAddWorkoutEntryFlow() throws {
        // Verify starting state
        XCTAssertTrue(viewModel.entries.isEmpty, "Should start with empty entries")

        // Create a complete workout entry as user would
        let exerciseName = "Integration Test Exercise"
        let sets = [
            ExerciseSet(reps: 10, weight: 50.0, notes: "Warmup set"),
            ExerciseSet(reps: 8, weight: 60.0, notes: "Working set"),
            ExerciseSet(reps: 6, weight: 65.0, notes: "Heavy set")
        ]

        let entry = ExerciseEntry(exerciseName: exerciseName, date: Date(), sets: sets)

        // Add entry through ViewModel (simulates user action)
        viewModel.addEntry(entry)

        // Verify immediate state changes
        XCTAssertEqual(viewModel.entries.count, 1, "Should have one entry after adding")
        XCTAssertEqual(viewModel.entries.first?.exerciseName, exerciseName)
        XCTAssertEqual(viewModel.entries.first?.sets.count, 3)

        // Verify persistence by creating new ViewModel with same DataStore
        let newViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(newViewModel.entries.count, 1, "Entry should persist across ViewModel instances")
        XCTAssertEqual(newViewModel.entries.first?.exerciseName, exerciseName)
    }

    func testCompleteDeleteWorkoutFlow() throws {
        // Setup: Add multiple entries
        let entries = [
            ExerciseEntry(exerciseName: "Exercise 1", date: Date(), sets: [
                ExerciseSet(reps: 10, weight: 50.0, notes: nil)
            ]),
            ExerciseEntry(exerciseName: "Exercise 2", date: Date(), sets: [
                ExerciseSet(reps: 12, weight: 40.0, notes: nil)
            ]),
            ExerciseEntry(exerciseName: "Exercise 3", date: Date(), sets: [
                ExerciseSet(reps: 8, weight: 70.0, notes: nil)
            ])
        ]

        for entry in entries {
            viewModel.addEntry(entry)
        }

        XCTAssertEqual(viewModel.entries.count, 3, "Should have 3 entries after setup")

        // Delete middle entry (index 1)
        let indexSet = IndexSet([1])
        viewModel.deleteEntry(at: indexSet)

        // Verify deletion and remaining entries
        XCTAssertEqual(viewModel.entries.count, 2, "Should have 2 entries after deletion")
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Exercise 1")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Exercise 3")

        // Verify persistence of deletion
        let newViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(newViewModel.entries.count, 2, "Deletion should persist")
        XCTAssertFalse(newViewModel.entries.contains { $0.exerciseName == "Exercise 2" })
    }

    func testCompleteDataExportFlow() throws {
        // Setup: Add test data
        let testEntries = [
            ExerciseEntry(exerciseName: "Bench Press", date: Date(), sets: [
                ExerciseSet(reps: 10, weight: 60.0, notes: "Good form"),
                ExerciseSet(reps: 8, weight: 65.0, notes: "Felt heavy")
            ]),
            ExerciseEntry(exerciseName: "Squats", date: Date().addingTimeInterval(-3600), sets: [
                ExerciseSet(reps: 12, weight: 80.0, notes: "Deep reps"),
                ExerciseSet(reps: 10, weight: 85.0, notes: nil)
            ])
        ]

        for entry in testEntries {
            viewModel.addEntry(entry)
        }

        // Export data
        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should return a valid URL")
            return
        }

        // Verify export file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify export content by loading and decoding
        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        XCTAssertEqual(decodedEntries.count, 2, "Export should contain all entries")
        XCTAssertTrue(decodedEntries.contains { $0.exerciseName == "Bench Press" })
        XCTAssertTrue(decodedEntries.contains { $0.exerciseName == "Squats" })

        // Verify detailed data integrity
        let benchEntry = decodedEntries.first { $0.exerciseName == "Bench Press" }
        XCTAssertNotNil(benchEntry)
        XCTAssertEqual(benchEntry?.sets.count, 2)
        XCTAssertEqual(benchEntry?.sets.first?.notes, "Good form")
    }

    func testCompleteDataPersistenceFlow() throws {
        // Test complete persistence cycle across multiple sessions
        let originalDate = Date()

        // Session 1: Add data
        let entry1 = ExerciseEntry(exerciseName: "Session 1 Exercise", date: originalDate, sets: [
            ExerciseSet(reps: 15, weight: 45.0, notes: "Light day")
        ])
        viewModel.addEntry(entry1)

        // Verify immediate persistence
        let session1ViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(session1ViewModel.entries.count, 1)

        // Session 2: Add more data
        let entry2 = ExerciseEntry(
            exerciseName: "Session 2 Exercise",
            date: originalDate.addingTimeInterval(3600),
            sets: [
            ExerciseSet(reps: 10, weight: 55.0, notes: "Medium intensity")
            ])
        session1ViewModel.addEntry(entry2)

        // Session 3: Verify all data persists
        let session3ViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(session3ViewModel.entries.count, 2)

        let exerciseNames = session3ViewModel.entries.map { $0.exerciseName }
        XCTAssertTrue(exerciseNames.contains("Session 1 Exercise"))
        XCTAssertTrue(exerciseNames.contains("Session 2 Exercise"))

        // Session 4: Delete and verify persistence
        let deleteIndexSet = IndexSet([0])
        session3ViewModel.deleteEntry(at: deleteIndexSet)

        let session4ViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(session4ViewModel.entries.count, 1)
    }

    func testEdgeCaseWorkflows() throws {
        // Test workflow with edge case data
        let specialEntry = ExerciseEntry(
            exerciseName: "🏋️‍♂️ Special Characters & \"Quotes\" Test",
            date: Date(),
            sets: [
                ExerciseSet(reps: 0, weight: nil, notes: "Failed attempt"),
                ExerciseSet(reps: 100, weight: 0.0, notes: "Body weight only"),
                ExerciseSet(reps: 1, weight: 200.0, notes: "Max effort 💪")
            ]
        )

        viewModel.addEntry(specialEntry)

        // Verify special characters persist correctly
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        let persistedEntry = persistedViewModel.entries.first

        XCTAssertNotNil(persistedEntry)
        XCTAssertEqual(persistedEntry?.exerciseName, "🏋️‍♂️ Special Characters & \"Quotes\" Test")
        XCTAssertEqual(persistedEntry?.sets.count, 3)
        XCTAssertEqual(persistedEntry?.sets[0].reps, 0)
        XCTAssertNil(persistedEntry?.sets[0].weight)
        XCTAssertEqual(persistedEntry?.sets[2].notes, "Max effort 💪")

        // Test export with special characters
        guard let exportURL = persistedViewModel.exportJSON() else {
            XCTFail("Export should return a valid URL")
            return
        }
        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        XCTAssertEqual(exportedEntries.first?.exerciseName, specialEntry.exerciseName)
    }
}
