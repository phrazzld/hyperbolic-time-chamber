import XCTest
@testable import WorkoutTracker

/// Focused test suite for ExerciseEntry model validation
final class ExerciseEntryTests: XCTestCase {

    // MARK: - Basic Initialization Tests

    func testExerciseEntryInitialization() {
        // Test basic initialization
        let date = Date()
        let sets = [
            ExerciseSet(reps: 10, weight: 50.0, notes: "First set"),
            ExerciseSet(reps: 8, weight: 55.0, notes: nil)
        ]

        let entry = ExerciseEntry(exerciseName: "Bench Press", date: date, sets: sets)

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.exerciseName, "Bench Press")
        XCTAssertEqual(entry.date, date)
        XCTAssertEqual(entry.sets.count, 2)
        XCTAssertEqual(entry.sets[0].reps, 10)
        XCTAssertEqual(entry.sets[1].weight, 55.0)
    }

    func testExerciseEntryUniqueIDs() {
        // Test that each entry gets a unique ID
        let entry1 = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])
        let entry2 = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])

        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testExerciseEntryWithEmptySets() {
        // Test entry with no sets
        let entry = ExerciseEntry(exerciseName: "Empty Exercise", date: Date(), sets: [])

        XCTAssertEqual(entry.exerciseName, "Empty Exercise")
        XCTAssertTrue(entry.sets.isEmpty)
    }

    func testExerciseEntryWithSpecialCharacters() {
        // Test exercise names with special characters
        let specialNames = [
            "Push-ups & Pull-ups",
            "90° Leg Raises",
            "Плавание (Swimming)",
            "🏋️‍♂️ Heavy Squats",
            "Exercise \"with quotes\"",
            "Multi\nLine\nExercise"
        ]

        for name in specialNames {
            let entry = ExerciseEntry(exerciseName: name, date: Date(), sets: [])
            XCTAssertEqual(entry.exerciseName, name)
        }
    }

    // MARK: - Date Handling Tests

    func testExerciseEntryDatePrecision() {
        // Test date handling with specific timestamps
        let specificDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let entry = ExerciseEntry(exerciseName: "New Year Workout", date: specificDate, sets: [])

        XCTAssertEqual(entry.date.timeIntervalSince1970, 1609459200, accuracy: 0.001)
    }

    func testExerciseEntryDateBoundaries() {
        // Test with various date boundaries
        let dates = [
            Date(timeIntervalSince1970: 0), // Unix epoch
            Date(timeIntervalSince1970: 946684800), // Y2K
            Date(), // Current time
            Date.distantPast,
            Date.distantFuture
        ]

        for date in dates {
            let entry = ExerciseEntry(exerciseName: "Boundary Test", date: date, sets: [])
            XCTAssertEqual(entry.date, date)
        }
    }
}
