import XCTest
import Foundation
@testable import WorkoutTracker

/// Integration tests for complete data persistence workflows
final class CompletePersistenceWorkflowTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()

        // Create isolated temporary directory for each test
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        dataStore = DataStore(baseDirectory: temporaryDirectory)
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        dataStore = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Complete Lifecycle Workflows

    func testCompleteAddEntryPersistenceLifecycle() throws {
        // Arrange: Create sample workout entry
        let originalEntry = ExerciseEntry(
            exerciseName: "Integration Test Exercise",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [
                ExerciseSet(reps: 10, weight: 50.0),
                ExerciseSet(reps: 8, weight: 55.0)
            ]
        )

        // Act 1: Add entry to ViewModel (triggers automatic save)
        XCTAssertTrue(viewModel.entries.isEmpty, "ViewModel should start empty")
        viewModel.addEntry(originalEntry)
        XCTAssertEqual(viewModel.entries.count, 1, "ViewModel should contain 1 entry after adding")

        // Act 2: Simulate app restart by creating fresh ViewModel with same DataStore
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Verify data survived persistence round-trip
        XCTAssertEqual(freshViewModel.entries.count, 1, "Fresh ViewModel should load 1 entry from disk")

        let loadedEntry = try XCTUnwrap(freshViewModel.entries.first, "Should have loaded entry")
        XCTAssertEqual(loadedEntry.id, originalEntry.id, "Entry ID should be preserved")
        XCTAssertEqual(loadedEntry.exerciseName, originalEntry.exerciseName, "Exercise name should be preserved")
        XCTAssertEqual(loadedEntry.date.timeIntervalSince1970,
                       originalEntry.date.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Date should be preserved with reasonable precision")
        XCTAssertEqual(loadedEntry.sets.count, 2, "Should have preserved both sets")
        XCTAssertEqual(loadedEntry.sets[0].reps, 10, "First set reps should be preserved")
        XCTAssertEqual(loadedEntry.sets[0].weight, 50.0, "First set weight should be preserved")
        XCTAssertEqual(loadedEntry.sets[1].reps, 8, "Second set reps should be preserved")
        XCTAssertEqual(loadedEntry.sets[1].weight, 55.0, "Second set weight should be preserved")
    }

    func testCompleteDeleteEntryPersistenceLifecycle() throws {
        // Arrange: Add multiple entries
        let entries = [
            ExerciseEntry(exerciseName: "Exercise 1",
                          date: Date(timeIntervalSince1970: 1672531200),
                          sets: [ExerciseSet(reps: 10, weight: 50.0)]),
            ExerciseEntry(exerciseName: "Exercise 2",
                          date: Date(timeIntervalSince1970: 1672531300),
                          sets: [ExerciseSet(reps: 12, weight: 60.0)]),
            ExerciseEntry(exerciseName: "Exercise 3",
                          date: Date(timeIntervalSince1970: 1672531400),
                          sets: [ExerciseSet(reps: 8, weight: 70.0)])
        ]

        for entry in entries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 3, "Should have 3 entries after adding")

        // Act 1: Delete middle entry (index 1)
        let middleEntryId = viewModel.entries[1].id
        viewModel.deleteEntry(at: IndexSet([1]))
        XCTAssertEqual(viewModel.entries.count, 2, "Should have 2 entries after deletion")
        XCTAssertFalse(viewModel.entries.contains { $0.id == middleEntryId }, "Deleted entry should be gone")

        // Act 2: Simulate app restart
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Verify deletion persisted correctly
        XCTAssertEqual(freshViewModel.entries.count, 2, "Fresh ViewModel should load 2 entries")
        XCTAssertFalse(freshViewModel.entries.contains { $0.id == middleEntryId },
                       "Deleted entry should not be loaded")
        XCTAssertTrue(freshViewModel.entries.contains { $0.exerciseName == "Exercise 1" },
                      "First entry should remain")
        XCTAssertTrue(freshViewModel.entries.contains { $0.exerciseName == "Exercise 3" },
                      "Third entry should remain")
    }

    // MARK: - Multi-Operation Workflows

    func testComplexMultiOperationWorkflow() throws {
        // Arrange: Start with empty state
        XCTAssertTrue(viewModel.entries.isEmpty, "Should start empty")

        // Act 1: Add multiple entries in sequence
        let initialEntries = [
            ExerciseEntry(exerciseName: "Push-ups",
                          date: Date(timeIntervalSince1970: 1672531200),
                          sets: [ExerciseSet(reps: 20, weight: nil)]),
            ExerciseEntry(exerciseName: "Squats",
                          date: Date(timeIntervalSince1970: 1672531300),
                          sets: [ExerciseSet(reps: 15, weight: 80.0)]),
            ExerciseEntry(exerciseName: "Pull-ups",
                          date: Date(timeIntervalSince1970: 1672531400),
                          sets: [ExerciseSet(reps: 8, weight: nil)])
        ]

        for entry in initialEntries {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 3, "Should have 3 entries")

        // Act 2: Delete one entry
        viewModel.deleteEntry(at: IndexSet([0])) // Delete Push-ups
        XCTAssertEqual(viewModel.entries.count, 2, "Should have 2 entries after deletion")

        // Act 3: Add another entry
        let additionalEntry = ExerciseEntry(
            exerciseName: "Deadlifts",
            date: Date(timeIntervalSince1970: 1672531500),
            sets: [ExerciseSet(reps: 5, weight: 120.0)]
        )
        viewModel.addEntry(additionalEntry)
        XCTAssertEqual(viewModel.entries.count, 3, "Should have 3 entries after adding")

        // Act 4: Export data to verify consistency
        let exportURL = try XCTUnwrap(viewModel.exportJSON(), "Export should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")

        // Act 5: Simulate app restart
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Verify final state after complex operations
        XCTAssertEqual(freshViewModel.entries.count, 3, "Should load 3 entries after restart")

        let exerciseNames = Set(freshViewModel.entries.map { $0.exerciseName })
        let expectedNames: Set<String> = ["Squats", "Pull-ups", "Deadlifts"]
        XCTAssertEqual(exerciseNames, expectedNames, "Should have correct exercises after complex workflow")

        // Verify export data matches loaded data
        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)
        XCTAssertEqual(exportedEntries.count, 3, "Exported data should match current state")

        let exportedNames = Set(exportedEntries.map { $0.exerciseName })
        XCTAssertEqual(exportedNames, expectedNames, "Exported data should match loaded data")
    }

    // MARK: - Data Integrity and Round-trip Testing

    func testDataIntegrityWithSpecialCharactersAndEdgeCases() throws {
        // Arrange: Create entries with challenging data
        let complexEntries = [
            ExerciseEntry(
                exerciseName: "Exercise with émojis 💪 and spëcial chârs",
                date: Date(timeIntervalSince1970: 1672531200.123456), // High precision timestamp
                sets: [
                    ExerciseSet(reps: 0, weight: nil), // Edge case: zero reps, no weight
                    ExerciseSet(reps: 1000, weight: 999.99), // Edge case: large numbers
                    ExerciseSet(reps: 1, weight: 0.1) // Edge case: small weight
                ]
            ),
            ExerciseEntry(
                exerciseName: "\"Quoted\" exercise with\nnewlines and\ttabs",
                date: Date(timeIntervalSince1970: 1672531200.999999),
                sets: [ExerciseSet(reps: 42, weight: 42.42)]
            )
        ]

        // Act: Add entries and persist
        for entry in complexEntries {
            viewModel.addEntry(entry)
        }

        // Simulate app restart
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Verify all special characters and edge cases are preserved
        XCTAssertEqual(freshViewModel.entries.count, 2, "Should load 2 complex entries")

        let emojiEntry = freshViewModel.entries.first { $0.exerciseName.contains("émojis") }
        let quotedEntry = freshViewModel.entries.first { $0.exerciseName.contains("Quoted") }

        let originalEmojiEntry = complexEntries[0]
        let originalQuotedEntry = complexEntries[1]

        // Verify emoji entry
        XCTAssertNotNil(emojiEntry, "Emoji entry should be loaded")
        XCTAssertEqual(emojiEntry?.exerciseName,
                       originalEmojiEntry.exerciseName,
                       "Emoji exercise name should be preserved")
        XCTAssertEqual(emojiEntry?.sets.count, 3, "Should preserve all 3 sets")
        XCTAssertEqual(emojiEntry?.sets[0].reps, 0, "Zero reps should be preserved")
        XCTAssertNil(emojiEntry?.sets[0].weight, "Nil weight should be preserved")
        XCTAssertEqual(emojiEntry?.sets[1].reps, 1000, "Large reps should be preserved")
        XCTAssertEqual(emojiEntry?.sets[1].weight, 999.99, "Large weight should be preserved")

        // Verify quoted entry with special characters
        XCTAssertNotNil(quotedEntry, "Quoted entry should be loaded")
        XCTAssertEqual(quotedEntry?.exerciseName,
                       originalQuotedEntry.exerciseName,
                       "Special characters should be preserved")
        XCTAssertEqual(quotedEntry?.sets[0].weight, 42.42, "Decimal weight should be preserved")
    }

    // MARK: - Concurrent Operations and Consistency

    func testRapidSequentialOperationsConsistency() throws {
        // Arrange: Prepare for rapid operations
        var allEntries: [ExerciseEntry] = []

        // Act: Perform rapid sequential add/delete operations
        for entryIndex in 0..<20 {
            let entry = ExerciseEntry(
                exerciseName: "Rapid Entry \(entryIndex)",
                date: Date(timeIntervalSince1970: 1672531200 + Double(entryIndex)),
                sets: [ExerciseSet(reps: entryIndex + 1, weight: Double(entryIndex) * 10.0)]
            )
            allEntries.append(entry)
            viewModel.addEntry(entry)
        }

        XCTAssertEqual(viewModel.entries.count, 20, "Should have 20 entries after rapid adding")

        // Delete every other entry rapidly
        let indicesToDelete = Array(stride(from: 18, through: 0, by: -2)) // Delete backwards to maintain indices
        for index in indicesToDelete {
            viewModel.deleteEntry(at: IndexSet([index]))
        }

        XCTAssertEqual(viewModel.entries.count, 10, "Should have 10 entries after rapid deletion")

        // Act: Simulate app restart to verify consistency
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Verify consistency after rapid operations
        XCTAssertEqual(freshViewModel.entries.count, 10, "Should consistently load 10 entries")

        // Verify all remaining entries have odd numbers (since we deleted even indices)
        for entry in freshViewModel.entries {
            let entryNumber = Int(entry.exerciseName.components(separatedBy: " ").last ?? "0") ?? 0
            XCTAssertTrue(entryNumber % 2 == 1, "Should only have odd-numbered entries remaining")
        }
    }

    // MARK: - Large Dataset Workflows

    func testLargeDatasetPersistenceWorkflow() throws {
        // Arrange: Generate large dataset (100 entries with multiple sets each)
        let largeDataset = (0..<100).map { exerciseIndex in
            ExerciseEntry(
                exerciseName: "Exercise \(exerciseIndex)",
                date: Date(timeIntervalSince1970: 1672531200 + Double(exerciseIndex * 60)), // 1 minute apart
                sets: (0..<(exerciseIndex % 5 + 1)).map { setIndex in // 1-5 sets per exercise
                    ExerciseSet(reps: 10 + setIndex, weight: Double(50 + exerciseIndex))
                }
            )
        }

        // Act: Add all entries (this will trigger 100 save operations)
        let startTime = Date()
        for entry in largeDataset {
            viewModel.addEntry(entry)
        }
        let addTime = Date().timeIntervalSince(startTime)

        XCTAssertEqual(viewModel.entries.count, 100, "Should have 100 entries")
        XCTAssertLessThan(addTime, 10.0, "Adding 100 entries should complete within 10 seconds")

        // Act: Simulate app restart and measure load time
        let loadStartTime = Date()
        let freshViewModel = WorkoutViewModel(dataStore: dataStore)
        let loadTime = Date().timeIntervalSince(loadStartTime)

        // Assert: Verify large dataset integrity and performance
        XCTAssertEqual(freshViewModel.entries.count, 100, "Should load all 100 entries")
        XCTAssertLessThan(loadTime, 5.0, "Loading 100 entries should complete within 5 seconds")

        // Verify data integrity across large dataset
        let originalIds = Set(largeDataset.map { $0.id })
        let loadedIds = Set(freshViewModel.entries.map { $0.id })
        XCTAssertEqual(originalIds, loadedIds, "All entry IDs should be preserved")

        // Verify total sets count
        let originalSetsCount = largeDataset.flatMap { $0.sets }.count
        let loadedSetsCount = freshViewModel.entries.flatMap { $0.sets }.count
        XCTAssertEqual(originalSetsCount, loadedSetsCount, "All sets should be preserved")

        // Test export with large dataset
        let exportURL = try XCTUnwrap(freshViewModel.exportJSON(), "Export should succeed with large dataset")
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")

        // Verify export file size is reasonable (not empty, not excessively large)
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: exportURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Export file should be substantial for 100 entries")
        XCTAssertLessThan(fileSize, 10_000_000, "Export file should not be excessively large")
    }

    // MARK: - Error Recovery and Resilience

    func testGracefulHandlingOfCorruptedData() throws {
        // Arrange: Create valid data first
        let validEntry = ExerciseEntry(
            exerciseName: "Valid Exercise",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [ExerciseSet(reps: 10, weight: 50.0)]
        )
        viewModel.addEntry(validEntry)

        // Get the file URL and corrupt the data
        let fileURL = temporaryDirectory.appendingPathComponent("workout_entries.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Data file should exist")

        // Act: Corrupt the JSON file
        let corruptedData = Data("{ invalid json content }".utf8)
        try corruptedData.write(to: fileURL)

        // Act: Create fresh ViewModel with corrupted data
        let resilientViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: ViewModel should gracefully handle corruption by starting empty
        XCTAssertEqual(resilientViewModel.entries.count,
                       0,
                       "ViewModel should start empty when data is corrupted")

        // Verify the ViewModel can recover by adding new data
        let recoveryEntry = ExerciseEntry(
            exerciseName: "Recovery Exercise",
            date: Date(timeIntervalSince1970: 1672531300),
            sets: [ExerciseSet(reps: 5, weight: 25.0)]
        )
        resilientViewModel.addEntry(recoveryEntry)

        // Verify recovery persists
        let finalViewModel = WorkoutViewModel(dataStore: dataStore)
        XCTAssertEqual(finalViewModel.entries.count, 1, "Should have recovered with new data")
        XCTAssertEqual(finalViewModel.entries[0].exerciseName,
                       "Recovery Exercise",
                       "Recovery data should be preserved")
    }

    func testHandlingOfMissingDataFile() throws {
        // Arrange: Ensure no data file exists
        let fileURL = temporaryDirectory.appendingPathComponent("workout_entries.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                       "Data file should not exist initially")

        // Act: Create ViewModel with missing data file
        let cleanViewModel = WorkoutViewModel(dataStore: dataStore)

        // Assert: Should start with empty state gracefully
        XCTAssertEqual(cleanViewModel.entries.count, 0, "Should start empty with missing file")

        // Add data and verify it creates the file
        let firstEntry = ExerciseEntry(
            exerciseName: "First Exercise",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [ExerciseSet(reps: 10, weight: 50.0)]
        )
        cleanViewModel.addEntry(firstEntry)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "Data file should be created after first save")

        // Verify persistence works normally after initial creation
        let verificationViewModel = WorkoutViewModel(dataStore: dataStore)
        XCTAssertEqual(verificationViewModel.entries.count, 1, "Should load data from newly created file")
    }
}
