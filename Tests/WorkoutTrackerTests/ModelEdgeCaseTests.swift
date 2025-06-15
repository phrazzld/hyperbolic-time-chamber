import XCTest
@testable import WorkoutTracker

/// Edge case and integration tests for model behavior
final class ModelEdgeCaseTests: XCTestCase {

    // MARK: - Edge Case Tests

    func testExerciseEntryWithExtremelyLongName() {
        // Test with very long exercise name
        let longName = String(repeating: "A", count: 10000)
        let entry = ExerciseEntry(exerciseName: longName, date: Date(), sets: [])

        XCTAssertEqual(entry.exerciseName, longName)
        XCTAssertEqual(entry.exerciseName.count, 10000)
    }

    func testExerciseEntryWithManySets() {
        // Test with many sets
        let manySets = (1...100).map { index in
            ExerciseSet(reps: index, weight: Double(index), notes: "Set \(index)")
        }

        let entry = ExerciseEntry(exerciseName: "Endurance Test", date: Date(), sets: manySets)

        XCTAssertEqual(entry.sets.count, 100)
        XCTAssertEqual(entry.sets.first?.reps, 1)
        XCTAssertEqual(entry.sets.last?.reps, 100)
    }

    func testFloatingPointPrecision() {
        // Test floating point precision with weights
        let preciseWeights = [
            0.1, 0.25, 0.33333333, 0.5, 0.66666666, 0.75, 0.9,
            1.1, 2.5, 3.33333333, 5.0, 10.5, 25.25, 50.75, 100.99
        ]

        for weight in preciseWeights {
            let set = ExerciseSet(reps: 1, weight: weight, notes: nil)
            XCTAssertEqual(set.weight ?? 0, weight, accuracy: 0.00001)
        }
    }

    func testUnicodeHandling() {
        // Test comprehensive Unicode support
        let unicodeExercises = [
            "Упражнение", // Cyrillic
            "エクササイズ", // Japanese
            "운동", // Korean
            "تمرين", // Arabic
            "व्यायाम", // Hindi
            "锻炼", // Chinese Simplified
            "🏋️‍♂️💪🔥", // Emoji
            "Café Übung", // Latin with diacritics
            "Ελληνικά", // Greek
            "עברית" // Hebrew
        ]

        for exerciseName in unicodeExercises {
            let entry = ExerciseEntry(exerciseName: exerciseName, date: Date(), sets: [])
            XCTAssertEqual(entry.exerciseName, exerciseName)
        }
    }

    // MARK: - Model Relationship Tests

    func testExerciseEntrySetRelationship() {
        // Test the relationship between entries and their sets
        let sets = [
            ExerciseSet(reps: 10, weight: 50.0, notes: "Set 1"),
            ExerciseSet(reps: 8, weight: 55.0, notes: "Set 2"),
            ExerciseSet(reps: 6, weight: 60.0, notes: "Set 3")
        ]

        let entry = ExerciseEntry(exerciseName: "Progressive Overload", date: Date(), sets: sets)

        // Verify all sets are included
        XCTAssertEqual(entry.sets.count, 3)

        // Verify order is preserved
        XCTAssertEqual(entry.sets[0].notes, "Set 1")
        XCTAssertEqual(entry.sets[1].notes, "Set 2")
        XCTAssertEqual(entry.sets[2].notes, "Set 3")

        // Verify progressive weights
        XCTAssertLessThan(entry.sets[0].weight ?? 0, entry.sets[1].weight ?? 0)
        XCTAssertLessThan(entry.sets[1].weight ?? 0, entry.sets[2].weight ?? 0)
    }

    func testModelIdentityConsistency() {
        // Test that model IDs remain consistent throughout operations
        let set = ExerciseSet(reps: 10, weight: 50.0, notes: "Test")
        let originalSetId = set.id

        let entry = ExerciseEntry(exerciseName: "Identity Test", date: Date(), sets: [set])
        let originalEntryId = entry.id

        // IDs should remain the same after inclusion in collections
        XCTAssertEqual(entry.sets[0].id, originalSetId)
        XCTAssertEqual(entry.id, originalEntryId)
    }
}
