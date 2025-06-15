import XCTest
@testable import WorkoutTracker

/// Basic test suite to verify XCTest target is properly configured
final class WorkoutTrackerTests: XCTestCase {

    func testXCTestTargetConfiguration() {
        // This test verifies that the XCTest target is properly configured
        // and can import the main WorkoutTracker module
        XCTAssertTrue(true, "XCTest target configuration successful")
    }

    func testExerciseEntryCreation() {
        // Basic test to verify models can be instantiated
        let exerciseSet = ExerciseSet(reps: 10, weight: 50.0)
        let entry = ExerciseEntry(
            exerciseName: "Test Exercise",
            date: Date(),
            sets: [exerciseSet]
        )

        XCTAssertEqual(entry.exerciseName, "Test Exercise")
        XCTAssertEqual(entry.sets.count, 1)
        XCTAssertEqual(entry.sets.first?.reps, 10)
        XCTAssertEqual(entry.sets.first?.weight, 50.0)
    }

    func testExerciseSetCreation() {
        // Test ExerciseSet model
        let setWithWeight = ExerciseSet(reps: 12, weight: 75.5)
        let setWithoutWeight = ExerciseSet(reps: 15, weight: nil)

        XCTAssertEqual(setWithWeight.reps, 12)
        XCTAssertEqual(setWithWeight.weight, 75.5)

        XCTAssertEqual(setWithoutWeight.reps, 15)
        XCTAssertNil(setWithoutWeight.weight)
    }
}
