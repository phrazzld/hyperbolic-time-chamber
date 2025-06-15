import XCTest
@testable import WorkoutTracker

/// Focused test suite for ExerciseSet model validation
final class ExerciseSetTests: XCTestCase {

    // MARK: - Basic Initialization Tests

    func testExerciseSetInitialization() {
        // Test basic initialization
        let set = ExerciseSet(reps: 10, weight: 50.0, notes: "Good form")

        XCTAssertNotNil(set.id)
        XCTAssertEqual(set.reps, 10)
        XCTAssertEqual(set.weight, 50.0)
        XCTAssertEqual(set.notes, "Good form")
    }

    func testExerciseSetUniqueIDs() {
        // Test that each set gets a unique ID
        let set1 = ExerciseSet(reps: 10, weight: 50.0, notes: nil)
        let set2 = ExerciseSet(reps: 10, weight: 50.0, notes: nil)

        XCTAssertNotEqual(set1.id, set2.id)
    }

    func testExerciseSetWithNilNotes() {
        // Test set with no notes
        let set = ExerciseSet(reps: 8, weight: 45.0, notes: nil)

        XCTAssertEqual(set.reps, 8)
        XCTAssertEqual(set.weight, 45.0)
        XCTAssertNil(set.notes)
    }

    // MARK: - Boundary Value Tests

    func testExerciseSetWithZeroValues() {
        // Test with zero values
        let set = ExerciseSet(reps: 0, weight: 0.0, notes: "Warmup")

        XCTAssertEqual(set.reps, 0)
        XCTAssertEqual(set.weight, 0.0)
        XCTAssertEqual(set.notes, "Warmup")
    }

    func testExerciseSetWithLargeValues() {
        // Test with large values
        let set = ExerciseSet(reps: 1000, weight: 999.99, notes: "Max test")

        XCTAssertEqual(set.reps, 1000)
        XCTAssertEqual(set.weight ?? 0, 999.99, accuracy: 0.001)
        XCTAssertEqual(set.notes, "Max test")
    }

    func testExerciseSetWithNegativeValues() {
        // Test with negative values (should still work for data integrity)
        let set = ExerciseSet(reps: -1, weight: -10.0, notes: "Invalid data test")

        XCTAssertEqual(set.reps, -1)
        XCTAssertEqual(set.weight, -10.0)
        XCTAssertEqual(set.notes, "Invalid data test")
    }

    // MARK: - Notes Validation Tests

    func testExerciseSetWithLongNotes() {
        // Test with very long notes
        let longNotes = String(repeating: "A", count: 1000)
        let set = ExerciseSet(reps: 5, weight: 25.0, notes: longNotes)

        XCTAssertEqual(set.notes, longNotes)
        XCTAssertEqual(set.notes?.count, 1000)
    }

    func testExerciseSetWithSpecialCharacterNotes() {
        // Test notes with special characters
        let specialNotes = [
            "Notes with émojis 🎯💪",
            "Multi\nline\nnotes",
            "Special chars: !@#$%^&*()",
            "Unicode: 测试 тест テスト",
            "\"Quoted\" notes with 'apostrophes'"
        ]

        for notes in specialNotes {
            let set = ExerciseSet(reps: 5, weight: 25.0, notes: notes)
            XCTAssertEqual(set.notes, notes)
        }
    }
}
