import XCTest
@testable import WorkoutTracker
import Foundation
import TestConfiguration

/// Comprehensive test suite for DataStore save/load operations and error handling
final class DataStoreTests: XCTestCase {

    var dataStore: DataStore!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Create a temp directory for testing to avoid interfering with real data
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Initialize DataStore with test directory
        dataStore = DataStore(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        // Clean up temp files
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadEmptyFile() {
        // Test loading when no data file exists
        let entries = dataStore.load()
        XCTAssertTrue(entries.isEmpty, "Should return empty array when no file exists")
    }

    func testLoadInvalidJSON() {
        // Test loading when JSON is corrupted
        let invalidJSON = "{ invalid json }"
        let testURL = tempDirectory.appendingPathComponent("workout_entries.json")
        try? invalidJSON.write(to: testURL, atomically: true, encoding: .utf8)

        let entries = dataStore.load()
        XCTAssertTrue(entries.isEmpty, "Should return empty array for invalid JSON")
    }

    func testLoadValidData() {
        // Test loading valid exercise entries
        let testEntries = createTestEntries()
        dataStore.save(entries: testEntries)

        let loadedEntries = dataStore.load()
        XCTAssertEqual(loadedEntries.count, testEntries.count)
        XCTAssertEqual(loadedEntries.first?.exerciseName, testEntries.first?.exerciseName)
        XCTAssertEqual(loadedEntries.first?.sets.count, testEntries.first?.sets.count)
    }

    // MARK: - Save Tests

    func testSaveEmptyArray() {
        // Test saving empty array
        dataStore.save(entries: [])
        let loadedEntries = dataStore.load()
        XCTAssertTrue(loadedEntries.isEmpty, "Should save and load empty array correctly")
    }

    func testSaveAndLoadRoundTrip() {
        // Test complete save/load cycle with real data
        let testEntries = createTestEntries()
        dataStore.save(entries: testEntries)
        let loadedEntries = dataStore.load()

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
        dataStore.save(entries: [specialEntry])
        let loadedEntries = dataStore.load()

        XCTAssertEqual(loadedEntries.count, 1)
        XCTAssertEqual(loadedEntries.first?.exerciseName, "Push-ups & Pull-ups (30° incline)")
    }

    // MARK: - Export Tests

    func testExportValidData() {
        // Test exporting entries to a shareable file
        let testEntries = createTestEntries()
        let exportURL = dataStore.export(entries: testEntries)

        XCTAssertNotNil(exportURL, "Export should return a valid URL")
        guard let exportURL = exportURL else {
            XCTFail("Export URL is nil")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify exported data can be read back
        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData)

        XCTAssertNotNil(exportedEntries)
        XCTAssertEqual(exportedEntries?.count, testEntries.count)
    }

    func testExportEmptyArray() {
        // Test exporting empty array
        let exportURL = dataStore.export(entries: [])
        XCTAssertNotNil(exportURL, "Should be able to export empty array")

        guard let exportURL = exportURL else {
            XCTFail("Export URL is nil")
            return
        }

        guard let exportedData = try? Data(contentsOf: exportURL) else {
            XCTFail("Could not read exported file")
            return
        }

        let decoder = JSONDecoder()
        let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: exportedData)
        XCTAssertNotNil(exportedEntries)
        XCTAssertTrue(exportedEntries?.isEmpty == true)
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

        dataStore.save(entries: [entry])
        let loadedEntries = dataStore.load()

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
