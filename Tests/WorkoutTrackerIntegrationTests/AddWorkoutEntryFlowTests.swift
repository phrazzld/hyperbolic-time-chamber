import XCTest
import Foundation
import Combine
@testable import WorkoutTracker

/// Comprehensive tests for the "Add new workout entry" complete user flow
/// Tests all scenarios and edge cases for adding workout entries to ensure robust functionality
final class AddWorkoutEntryFlowTests: XCTestCase {

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
        do {
            testDataStore = try FileDataStore(baseDirectory: tempDirectory)
        } catch {
            XCTFail("Failed to create FileDataStore: \(error)")
            return
        }

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

    // MARK: - Basic Add Workout Entry Flow Tests

    func testCompleteAddWorkoutEntryBasicFlow() throws {
        // Test the complete user flow for adding a basic workout entry
        XCTAssertTrue(viewModel.entries.isEmpty, "Should start with empty state")

        // Step 1: User creates a new exercise entry
        let exerciseName = "Bench Press"
        let currentDate = Date()

        // Step 2: User adds multiple sets with progression
        let warmupSet = ExerciseSet(reps: 12, weight: 45.0, notes: "Warmup with bar")
        let workingSet1 = ExerciseSet(reps: 10, weight: 135.0, notes: "First working set")
        let workingSet2 = ExerciseSet(reps: 8, weight: 155.0, notes: "Heavy set")
        let burnoutSet = ExerciseSet(reps: 15, weight: 95.0, notes: "Burnout to failure")

        let sets = [warmupSet, workingSet1, workingSet2, burnoutSet]

        // Step 3: User creates and saves the complete entry
        let entry = ExerciseEntry(exerciseName: exerciseName, date: currentDate, sets: sets)
        viewModel.addEntry(entry)

        // Step 4: Verify immediate UI state updates
        XCTAssertEqual(viewModel.entries.count, 1, "Should have one entry after adding")
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.exerciseName, exerciseName)
        XCTAssertEqual(savedEntry?.sets.count, 4)

        // Step 5: Verify set details are preserved correctly
        XCTAssertEqual(savedEntry?.sets[0].notes, "Warmup with bar")
        XCTAssertEqual(savedEntry?.sets[1].weight, 135.0)
        XCTAssertEqual(savedEntry?.sets[2].reps, 8)
        XCTAssertEqual(savedEntry?.sets[3].notes, "Burnout to failure")

        // Step 6: Verify data persistence across app sessions
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 1, "Entry should persist")
        XCTAssertEqual(persistedViewModel.entries.first?.exerciseName, exerciseName)
        XCTAssertEqual(persistedViewModel.entries.first?.sets.count, 4)
    }

    func testAddWorkoutEntryWithComplexSetProgression() throws {
        // Test adding a workout with complex set progression (pyramid training)
        let exerciseName = "Deadlifts"
        let trainingDate = Date()

        // Create pyramid progression: build up then back down
        let sets = [
            ExerciseSet(reps: 8, weight: 135.0, notes: "Warmup"),
            ExerciseSet(reps: 6, weight: 185.0, notes: "Build up"),
            ExerciseSet(reps: 4, weight: 225.0, notes: "Heavy"),
            ExerciseSet(reps: 2, weight: 275.0, notes: "Peak weight"),
            ExerciseSet(reps: 4, weight: 225.0, notes: "Back down"),
            ExerciseSet(reps: 6, weight: 185.0, notes: "Volume"),
            ExerciseSet(reps: 8, weight: 135.0, notes: "Finisher")
        ]

        let entry = ExerciseEntry(exerciseName: exerciseName, date: trainingDate, sets: sets)
        viewModel.addEntry(entry)

        // Verify the complex progression is preserved
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.sets.count, 7)

        // Verify pyramid pattern is intact
        XCTAssertEqual(savedEntry?.sets[0].reps, 8)
        XCTAssertEqual(savedEntry?.sets[3].reps, 2) // Peak
        XCTAssertEqual(savedEntry?.sets[6].reps, 8)

        // Verify weight progression
        XCTAssertEqual(savedEntry?.sets[3].weight, 275.0) // Peak weight
        XCTAssertEqual(savedEntry?.sets[0].weight, savedEntry?.sets[6].weight) // Same start/end
    }

    // MARK: - Special Characters and Text Handling

    func testAddWorkoutEntryWithSpecialCharactersAndEmojis() throws {
        // Test adding workout with international characters and emojis
        let complexExerciseName = "🏋️‍♂️ Αερόβιο + Cardio-интенсив \"Beast Mode\""
        let sets = [
            ExerciseSet(reps: 20, weight: nil, notes: "💪 Body weight only! 🔥🔥🔥"),
            ExerciseSet(reps: 15, weight: 0.0, notes: "Добавить вес в следующий раз"),
            ExerciseSet(reps: 12, weight: 10.5, notes: "Light resistance → progress!"),
            ExerciseSet(reps: 8, weight: 15.75, notes: "Final set \"all out\" effort ⚡")
        ]

        let entry = ExerciseEntry(exerciseName: complexExerciseName, date: Date(), sets: sets)
        viewModel.addEntry(entry)

        // Verify complex characters are preserved correctly
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.exerciseName, complexExerciseName)
        XCTAssertEqual(savedEntry?.sets[0].notes, "💪 Body weight only! 🔥🔥🔥")
        XCTAssertEqual(savedEntry?.sets[1].notes, "Добавить вес в следующий раз")
        XCTAssertEqual(savedEntry?.sets[3].notes, "Final set \"all out\" effort ⚡")

        // Verify persistence handles unicode correctly
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        let persistedEntry = persistedViewModel.entries.first
        XCTAssertEqual(persistedEntry?.exerciseName, complexExerciseName)
        XCTAssertEqual(persistedEntry?.sets[0].notes, "💪 Body weight only! 🔥🔥🔥")
    }

    // MARK: - Edge Cases and Boundary Values

    func testAddWorkoutEntryWithEdgeCaseValues() throws {
        // Test adding workout with boundary/edge case values
        let exerciseName = "Edge Case Testing"
        let sets = [
            // Zero values
            ExerciseSet(reps: 0, weight: 0.0, notes: "Failed attempt"),
            // High values
            ExerciseSet(reps: 1000, weight: 999.99, notes: "Endurance test"),
            // Precision values
            ExerciseSet(reps: 1, weight: 2.5, notes: "Micro-loading"),
            // Nil values
            ExerciseSet(reps: 25, weight: nil, notes: nil),
            // Empty notes
            ExerciseSet(reps: 10, weight: 50.0, notes: ""),
            // Long notes
            ExerciseSet(reps: 5, weight: 100.0, notes: String(repeating: "Long note text. ", count: 50))
        ]

        let entry = ExerciseEntry(exerciseName: exerciseName, date: Date(), sets: sets)
        viewModel.addEntry(entry)

        // Verify all edge cases are handled correctly
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.sets.count, 6)

        // Verify specific edge cases
        XCTAssertEqual(savedEntry?.sets[0].reps, 0)
        XCTAssertEqual(savedEntry?.sets[0].weight, 0.0)
        XCTAssertEqual(savedEntry?.sets[1].reps, 1000)
        XCTAssertEqual(savedEntry?.sets[1].weight, 999.99)
        XCTAssertNil(savedEntry?.sets[3].weight)
        XCTAssertNil(savedEntry?.sets[3].notes)
        XCTAssertEqual(savedEntry?.sets[4].notes, "")
        XCTAssertTrue(savedEntry?.sets[5].notes?.count ?? 0 >= 800) // Long note preserved
    }

    // MARK: - Date and Time Handling

    func testAddWorkoutEntryWithCustomDate() throws {
        // Test adding workout entry with specific past date
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            XCTFail("Failed to create past date")
            return
        }
        let exerciseName = "Last Week's Workout"

        let entry = ExerciseEntry(
            exerciseName: exerciseName,
            date: pastDate,
            sets: [ExerciseSet(reps: 10, weight: 50.0, notes: "Retroactive entry")]
        )

        viewModel.addEntry(entry)

        // Verify custom date is preserved
        guard let savedEntry = viewModel.entries.first else {
            XCTFail("Should have saved entry")
            return
        }
        XCTAssertEqual(savedEntry.date.timeIntervalSince1970,
                       pastDate.timeIntervalSince1970,
                       accuracy: 1.0)

        // Verify date persists correctly
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        guard let persistedEntry = persistedViewModel.entries.first else {
            XCTFail("Should have persisted entry")
            return
        }
        XCTAssertEqual(persistedEntry.date.timeIntervalSince1970,
                       pastDate.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    // MARK: - Multiple Entries and Sequences

    func testAddMultipleWorkoutEntriesInSequence() throws {
        // Test adding multiple workout entries in a session (simulates active training)
        XCTAssertTrue(viewModel.entries.isEmpty)

        let baseDate = Date()
        guard let squatsDate = Calendar.current.date(byAdding: .hour, value: -2, to: baseDate),
              let benchDate = Calendar.current.date(byAdding: .hour, value: -1, to: baseDate) else {
            XCTFail("Failed to create workout dates")
            return
        }

        let workouts = [
            ("Squats", squatsDate),
            ("Bench Press", benchDate),
            ("Rows", baseDate)
        ]

        // Add each workout with different characteristics
        for (index, (exerciseName, workoutDate)) in workouts.enumerated() {
            // Break down complex expression to avoid compiler timeout
            let sets: [ExerciseSet] = (1...3).compactMap { setIndex in
                let reps = 10 - setIndex
                let baseWeight = 50 + (index * 10)
                let weight = Double(baseWeight + setIndex * 5)
                let notes = "Set \(setIndex) of \(exerciseName)"

                return ExerciseSet(
                    reps: reps,
                    weight: weight,
                    notes: notes
                )
            }

            let entry = ExerciseEntry(exerciseName: exerciseName, date: workoutDate, sets: sets)
            viewModel.addEntry(entry)

            // Verify intermediate state after each addition
            XCTAssertEqual(viewModel.entries.count, index + 1)
        }

        // Verify final state
        XCTAssertEqual(viewModel.entries.count, 3)

        // Verify all entries have expected data
        let exerciseNames = viewModel.entries.map { $0.exerciseName }
        XCTAssertTrue(exerciseNames.contains("Squats"))
        XCTAssertTrue(exerciseNames.contains("Bench Press"))
        XCTAssertTrue(exerciseNames.contains("Rows"))

        // Verify persistence of all entries
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 3)
    }

    // MARK: - Minimal and Edge Cases

    func testAddWorkoutEntryWithSingleSetMinimalData() throws {
        // Test adding the simplest possible valid workout entry
        let entry = ExerciseEntry(
            exerciseName: "Quick Set",
            date: Date(),
            sets: [ExerciseSet(reps: 1, weight: nil, notes: nil)]
        )

        viewModel.addEntry(entry)

        // Verify minimal data is handled correctly
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.exerciseName, "Quick Set")
        XCTAssertEqual(savedEntry?.sets.count, 1)
        XCTAssertEqual(savedEntry?.sets.first?.reps, 1)
        XCTAssertNil(savedEntry?.sets.first?.weight)
        XCTAssertNil(savedEntry?.sets.first?.notes)

        // Verify minimal data persists
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 1)
        XCTAssertEqual(persistedViewModel.entries.first?.exerciseName, "Quick Set")
    }

    func testAddWorkoutEntryWithEmptyExerciseName() throws {
        // Test that empty exercise names are handled gracefully
        let entry = ExerciseEntry(
            exerciseName: "",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: 50.0, notes: "Empty name test")]
        )

        viewModel.addEntry(entry)

        // Verify empty name is preserved (business logic may validate elsewhere)
        let savedEntry = viewModel.entries.first
        XCTAssertNotNil(savedEntry)
        XCTAssertEqual(savedEntry?.exerciseName, "")
        XCTAssertEqual(savedEntry?.sets.count, 1)

        // Verify it persists correctly
        let persistedViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(persistedViewModel.entries.count, 1)
        XCTAssertEqual(persistedViewModel.entries.first?.exerciseName, "")
    }

    // MARK: - State Management

    func testAddWorkoutEntryStateManagement() throws {
        // Test that adding entries properly manages @Published state
        var entryCountUpdates: [Int] = []

        // Monitor @Published property changes
        let cancellable = viewModel.$entries
            .map { $0.count }
            .sink { count in
                entryCountUpdates.append(count)
            }

        // Add entries and verify state updates
        XCTAssertEqual(entryCountUpdates.last, 0) // Initial state

        let entry1 = ExerciseEntry(exerciseName: "First", date: Date(), sets: [
            ExerciseSet(reps: 10, weight: 50.0, notes: nil)
        ])
        viewModel.addEntry(entry1)
        XCTAssertEqual(entryCountUpdates.last, 1)

        let entry2 = ExerciseEntry(exerciseName: "Second", date: Date(), sets: [
            ExerciseSet(reps: 8, weight: 60.0, notes: nil)
        ])
        viewModel.addEntry(entry2)
        XCTAssertEqual(entryCountUpdates.last, 2)

        // Clean up
        cancellable.cancel()

        // Verify final state
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertTrue(entryCountUpdates.contains(0))
        XCTAssertTrue(entryCountUpdates.contains(1))
        XCTAssertTrue(entryCountUpdates.contains(2))
    }
}
