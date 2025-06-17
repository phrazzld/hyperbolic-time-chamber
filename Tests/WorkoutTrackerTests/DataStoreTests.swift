import XCTest
@testable import WorkoutTracker
import Foundation
import TestConfiguration

/// Comprehensive test suite for FileDataStore save/load operations and error handling
final class DataStoreTests: XCTestCase {

    var dataStore: FileDataStore!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Create a temp directory for testing to avoid interfering with real data
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Initialize FileDataStore with test directory
        do {
            dataStore = try FileDataStore(baseDirectory: tempDirectory)
        } catch {
            XCTFail("Failed to create FileDataStore: \(error)")
            return
        }
    }

    override func tearDown() {
        // Clean up temp files
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadEmptyFile() {
        // Test loading when no data file exists
        do {
            let entries = try dataStore.load()
            XCTAssertTrue(entries.isEmpty, "Should return empty array when no file exists")
        } catch {
            XCTFail("Load should not throw error when no file exists: \(error)")
        }
    }

    func testLoadInvalidJSON() {
        // Test loading when JSON is corrupted
        let invalidJSON = "{ invalid json }"
        let testURL = tempDirectory.appendingPathComponent("workout_entries.json")
        try? invalidJSON.write(to: testURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try dataStore.load()) { error in
            XCTAssertTrue(error is DataStoreError, "Should throw DataStoreError for invalid JSON")
            if case DataStoreError.loadFailed(_) = error {
                // Expected error type
            } else {
                XCTFail("Should throw loadFailed error")
            }
        }
    }

    func testLoadValidData() {
        // Test loading valid exercise entries
        let testEntries = createTestEntries()
        try? dataStore.save(entries: testEntries)

        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, testEntries.count)
            XCTAssertEqual(loadedEntries.first?.exerciseName, testEntries.first?.exerciseName)
            XCTAssertEqual(loadedEntries.first?.sets.count, testEntries.first?.sets.count)
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    // MARK: - Save Tests

    func testSaveEmptyArray() {
        // Test saving empty array
        try? dataStore.save(entries: [])
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertTrue(loadedEntries.isEmpty, "Should save and load empty array correctly")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testSaveAndLoadRoundTrip() {
        // Test complete save/load cycle with real data
        let testEntries = createTestEntries()
        try? dataStore.save(entries: testEntries)

        guard let loadedEntries = try? dataStore.load() else {
            XCTFail("Load should not throw error")
            return
        }

        XCTAssertEqual(loadedEntries.count, testEntries.count)

        for (original, loaded) in zip(testEntries, loadedEntries) {
            XCTAssertEqual(original.exerciseName, loaded.exerciseName)
            XCTAssertEqual(original.sets.count, loaded.sets.count)
            XCTAssertEqual(original.date.timeIntervalSince1970,
                           loaded.date.timeIntervalSince1970,
                           accuracy: 1.0) // Allow 1 second tolerance for ISO8601 precision

            for (originalSet, loadedSet) in zip(original.sets, loaded.sets) {
                XCTAssertEqual(originalSet.reps, loadedSet.reps)
                XCTAssertEqual(originalSet.weight, loadedSet.weight)
            }
        }
    }

    func testSaveWithSpecialCharacters() {
        // Test saving exercise names with special characters
        let specialEntry = ExerciseEntry(
            exerciseName: "Push-ups & Pull-ups (30° incline)",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: nil)]
        )
        try? dataStore.save(entries: [specialEntry])

        guard let loadedEntries = try? dataStore.load() else {
            XCTFail("Load should not throw error")
            return
        }

        XCTAssertEqual(loadedEntries.count, 1)
        XCTAssertEqual(loadedEntries.first?.exerciseName, "Push-ups & Pull-ups (30° incline)")
    }

    // MARK: - Export Tests

    func testExportValidData() {
        // Test exporting entries to a shareable file
        let testEntries = createTestEntries()

        guard let exportURL = try? dataStore.export(entries: testEntries) else {
            XCTFail("Export should not throw error")
            return
        }

        // exportURL is guaranteed to be valid since export() throws on failure
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify exported data can be read back
        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData) else {
            XCTFail("Could not decode exported data")
            return
        }

        XCTAssertEqual(exportedEntries.count, testEntries.count)
    }

    func testExportEmptyArray() {
        // Test exporting empty array
        guard let exportURL = try? dataStore.export(entries: []) else {
            XCTFail("Export should not throw error")
            return
        }
        // exportURL is guaranteed to be valid since export() throws on failure

        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        guard let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData) else {
            XCTFail("Could not decode exported data")
            return
        }
        XCTAssertTrue(exportedEntries.isEmpty)
    }

    // MARK: - Date Encoding/Decoding Tests

    func testDatePersistence() {
        // Test that dates are properly encoded/decoded with ISO8601
        let specificDate = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021 00:00:00 UTC
        let entry = ExerciseEntry(
            exerciseName: "Date Test",
            date: specificDate,
            sets: [ExerciseSet(reps: 1, weight: nil)]
        )

        try? dataStore.save(entries: [entry])

        guard let loadedEntries = try? dataStore.load() else {
            XCTFail("Load should not throw error")
            return
        }

        XCTAssertEqual(loadedEntries.count, 1)
        guard let firstEntry = loadedEntries.first else {
            XCTFail("No loaded entries found")
            return
        }
        XCTAssertEqual(firstEntry.date.timeIntervalSince1970,
                       specificDate.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    // MARK: - Helper Methods

    private func createTestEntries() -> [ExerciseEntry] {
        let entry1 = WorkoutTestDataFactory.createBasicEntry(
            name: "Bench Press",
            date: Date(),
            setCount: 2,
            baseReps: 10,
            baseWeight: 50.0
        )

        let entry2 = WorkoutTestDataFactory.createBodyweightEntry(
            name: "Push-ups",
            date: Date().addingTimeInterval(-3600) // 1 hour ago
        )

        return [entry1, entry2]
    }
}
