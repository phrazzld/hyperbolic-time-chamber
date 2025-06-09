import XCTest
@testable import WorkoutTracker

/// Comprehensive test suite for ExerciseEntry and ExerciseSet model validation
final class ModelValidationTests: XCTestCase {

    // MARK: - ExerciseEntry Tests

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

    func testExerciseEntryCodable() {
        // Test encoding and decoding
        let originalEntry = ExerciseEntry(
            exerciseName: "Deadlifts",
            date: Date(),
            sets: [
                ExerciseSet(reps: 5, weight: 100.0, notes: "Heavy"),
                ExerciseSet(reps: 3, weight: 120.0, notes: nil)
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(originalEntry)
            let decodedEntry = try decoder.decode(ExerciseEntry.self, from: data)

            // Note: We can't compare IDs as they'll be different after decoding
            XCTAssertEqual(decodedEntry.exerciseName, originalEntry.exerciseName)
            XCTAssertEqual(decodedEntry.sets.count, originalEntry.sets.count)
            XCTAssertEqual(decodedEntry.date.timeIntervalSince1970,
                           originalEntry.date.timeIntervalSince1970,
                           accuracy: 1.0)

            // Verify sets
            for (index, set) in decodedEntry.sets.enumerated() {
                XCTAssertEqual(set.reps, originalEntry.sets[index].reps)
                XCTAssertEqual(set.weight, originalEntry.sets[index].weight)
                XCTAssertEqual(set.notes, originalEntry.sets[index].notes)
            }
        } catch {
            XCTFail("Codable test failed: \(error)")
        }
    }

    func testExerciseEntryDatePrecision() {
        // Test date handling with specific timestamps
        let specificDate = Date(timeIntervalSince1970: 1609459200.123) // With milliseconds
        let entry = ExerciseEntry(exerciseName: "Test", date: specificDate, sets: [])

        XCTAssertEqual(entry.date.timeIntervalSince1970, specificDate.timeIntervalSince1970)
    }

    // MARK: - ExerciseSet Tests

    func testExerciseSetInitialization() {
        // Test initialization with all parameters
        let setWithAll = ExerciseSet(reps: 12, weight: 75.5, notes: "Good form")

        XCTAssertNotNil(setWithAll.id)
        XCTAssertEqual(setWithAll.reps, 12)
        XCTAssertEqual(setWithAll.weight, 75.5)
        XCTAssertEqual(setWithAll.notes, "Good form")
    }

    func testExerciseSetOptionalFields() {
        // Test initialization with optional fields nil
        let bodyweightSet = ExerciseSet(reps: 20, weight: nil, notes: nil)

        XCTAssertEqual(bodyweightSet.reps, 20)
        XCTAssertNil(bodyweightSet.weight)
        XCTAssertNil(bodyweightSet.notes)
    }

    func testExerciseSetUniqueIDs() {
        // Test that each set gets a unique ID
        let set1 = ExerciseSet(reps: 10, weight: 50.0, notes: nil)
        let set2 = ExerciseSet(reps: 10, weight: 50.0, notes: nil)

        XCTAssertNotEqual(set1.id, set2.id)
    }

    func testExerciseSetEdgeCases() {
        // Test edge case values
        let zeroReps = ExerciseSet(reps: 0, weight: 100.0, notes: "Failed rep")
        XCTAssertEqual(zeroReps.reps, 0)

        let negativeReps = ExerciseSet(reps: -5, weight: 50.0, notes: "Invalid")
        XCTAssertEqual(negativeReps.reps, -5) // Model allows it, validation would be elsewhere

        let zeroWeight = ExerciseSet(reps: 10, weight: 0.0, notes: "Bar only")
        XCTAssertEqual(zeroWeight.weight, 0.0)

        let negativeWeight = ExerciseSet(reps: 10, weight: -10.0, notes: "Invalid")
        XCTAssertEqual(negativeWeight.weight, -10.0) // Model allows it

        let highReps = ExerciseSet(reps: Int.max, weight: nil, notes: nil)
        XCTAssertEqual(highReps.reps, Int.max)

        let highWeight = ExerciseSet(reps: 1, weight: Double.greatestFiniteMagnitude, notes: nil)
        XCTAssertEqual(highWeight.weight, Double.greatestFiniteMagnitude)
    }

    func testExerciseSetLongNotes() {
        // Test very long notes
        let longNote = String(repeating: "Very long note. ", count: 1000)
        let set = ExerciseSet(reps: 10, weight: 50.0, notes: longNote)

        XCTAssertEqual(set.notes, longNote)
        XCTAssertEqual(set.notes?.count, 16000) // 16 chars * 1000
    }

    func testExerciseSetSpecialCharacterNotes() {
        // Test notes with special characters
        let specialNotes = [
            "Form was 💪 today!",
            "Struggled with last 2 reps\n\nNeed to lower weight",
            "«Хорошая тренировка»",
            "Weight: 50kg → 55kg next time",
            "🔥🔥🔥 PR! 🔥🔥🔥"
        ]

        for note in specialNotes {
            let set = ExerciseSet(reps: 10, weight: 50.0, notes: note)
            XCTAssertEqual(set.notes, note)
        }
    }

    func testExerciseSetCodable() {
        // Test encoding and decoding
        let originalSet = ExerciseSet(reps: 15, weight: 62.5, notes: "Last set best set")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(originalSet)
            let decodedSet = try decoder.decode(ExerciseSet.self, from: data)

            // Note: IDs will be different after decoding
            XCTAssertEqual(decodedSet.reps, originalSet.reps)
            XCTAssertEqual(decodedSet.weight, originalSet.weight)
            XCTAssertEqual(decodedSet.notes, originalSet.notes)
        } catch {
            XCTFail("Codable test failed: \(error)")
        }
    }

    func testExerciseSetCodableWithNilValues() {
        // Test encoding/decoding with nil optional fields
        let setWithNils = ExerciseSet(reps: 25, weight: nil, notes: nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(setWithNils)
            let decodedSet = try decoder.decode(ExerciseSet.self, from: data)

            XCTAssertEqual(decodedSet.reps, 25)
            XCTAssertNil(decodedSet.weight)
            XCTAssertNil(decodedSet.notes)
        } catch {
            XCTFail("Codable test failed: \(error)")
        }
    }

    // MARK: - Integration Tests

    func testExerciseEntryWithMultipleSets() {
        // Test complete exercise entry with various set configurations
        let sets = [
            ExerciseSet(reps: 12, weight: 60.0, notes: "Warmup"),
            ExerciseSet(reps: 10, weight: 80.0, notes: "Working set 1"),
            ExerciseSet(reps: 8, weight: 85.0, notes: "Working set 2"),
            ExerciseSet(reps: 6, weight: 90.0, notes: "Heavy!"),
            ExerciseSet(reps: 15, weight: 50.0, notes: "Burnout set")
        ]

        let entry = ExerciseEntry(
            exerciseName: "Progressive Overload Test",
            date: Date(),
            sets: sets
        )

        XCTAssertEqual(entry.sets.count, 5)

        // Verify sets maintain order
        XCTAssertEqual(entry.sets[0].notes, "Warmup")
        XCTAssertEqual(entry.sets[4].notes, "Burnout set")

        // Verify all data is preserved
        for (index, set) in entry.sets.enumerated() {
            XCTAssertEqual(set.reps, sets[index].reps)
            XCTAssertEqual(set.weight, sets[index].weight)
            XCTAssertEqual(set.notes, sets[index].notes)
        }
    }

    func testModelMemoryUsage() {
        // Test creating many models doesn't cause issues
        var entries: [ExerciseEntry] = []

        for entryIndex in 0..<100 {
            let sets = (0..<5).map { setIndex in
                ExerciseSet(
                    reps: 10 + setIndex,
                    weight: Double(50 + entryIndex),
                    notes: "Test note for set"
                )
            }

            let entry = ExerciseEntry(
                exerciseName: "Exercise Test",
                date: Date().addingTimeInterval(TimeInterval(entryIndex * 3600)),
                sets: sets
            )

            entries.append(entry)
        }

        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries[0].sets.count, 5)
        XCTAssertEqual(entries.last?.exerciseName, "Exercise Test")
    }
}
