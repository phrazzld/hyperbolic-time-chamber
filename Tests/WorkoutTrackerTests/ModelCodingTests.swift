import XCTest
@testable import WorkoutTracker

/// Focused test suite for model encoding/decoding validation
final class ModelCodingTests: XCTestCase {

    // MARK: - ExerciseEntry Coding Tests

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

    func testExerciseEntryArrayCoding() {
        // Test encoding/decoding arrays of entries
        let entries = [
            ExerciseEntry(exerciseName: "Squats", date: Date(), sets: [
                ExerciseSet(reps: 10, weight: 60.0, notes: "Warmup")
            ]),
            ExerciseEntry(exerciseName: "Bench Press", date: Date(), sets: [
                ExerciseSet(reps: 8, weight: 80.0, notes: "Working set"),
                ExerciseSet(reps: 6, weight: 90.0, notes: "Heavy")
            ])
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(entries)
            let decodedEntries = try decoder.decode([ExerciseEntry].self, from: data)

            XCTAssertEqual(decodedEntries.count, entries.count)

            for (index, decodedEntry) in decodedEntries.enumerated() {
                let originalEntry = entries[index]
                XCTAssertEqual(decodedEntry.exerciseName, originalEntry.exerciseName)
                XCTAssertEqual(decodedEntry.sets.count, originalEntry.sets.count)
            }
        } catch {
            XCTFail("Array coding test failed: \(error)")
        }
    }

    // MARK: - ExerciseSet Coding Tests

    func testExerciseSetCodable() {
        // Test encoding and decoding of individual sets
        let originalSet = ExerciseSet(reps: 12, weight: 75.5, notes: "Perfect form")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(originalSet)
            let decodedSet = try decoder.decode(ExerciseSet.self, from: data)

            XCTAssertEqual(decodedSet.reps, originalSet.reps)
            XCTAssertEqual(decodedSet.weight, originalSet.weight)
            XCTAssertEqual(decodedSet.notes, originalSet.notes)
        } catch {
            XCTFail("Set coding test failed: \(error)")
        }
    }

    func testExerciseSetWithNilNotesCoding() {
        // Test encoding/decoding sets with nil notes
        let originalSet = ExerciseSet(reps: 15, weight: 25.0, notes: nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(originalSet)
            let decodedSet = try decoder.decode(ExerciseSet.self, from: data)

            XCTAssertEqual(decodedSet.reps, originalSet.reps)
            XCTAssertEqual(decodedSet.weight, originalSet.weight)
            XCTAssertNil(decodedSet.notes)
        } catch {
            XCTFail("Nil notes coding test failed: \(error)")
        }
    }

    // MARK: - JSON Format Validation Tests

    func testJSONFormatCompatibility() {
        // Test that our models produce expected JSON format
        let entry = ExerciseEntry(
            exerciseName: "Test Exercise",
            date: Date(timeIntervalSince1970: 1609459200), // Fixed date for consistent testing
            sets: [
                ExerciseSet(reps: 10, weight: 50.0, notes: "Test notes")
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        do {
            let data = try encoder.encode(entry)
            let jsonString = String(data: data, encoding: .utf8)

            XCTAssertNotNil(jsonString)
            XCTAssertTrue(jsonString?.contains("\"exerciseName\":\"Test Exercise\"") == true)
            XCTAssertTrue(jsonString?.contains("\"reps\":10") == true)
            XCTAssertTrue(jsonString?.contains("\"weight\":50") == true)
        } catch {
            XCTFail("JSON format test failed: \(error)")
        }
    }
}
