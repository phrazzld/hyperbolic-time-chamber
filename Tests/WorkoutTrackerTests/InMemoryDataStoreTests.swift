import XCTest
@testable import WorkoutTracker
import Foundation

/// Comprehensive test suite for InMemoryDataStore functionality and protocol compliance
final class InMemoryDataStoreTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithEmptyEntries() {
        let dataStore = InMemoryDataStore()
        do {
            let entries = try dataStore.load()
            XCTAssertTrue(entries.isEmpty, "InMemoryDataStore should initialize with empty entries")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testInitWithPreloadedEntries() {
        let testEntries = createTestEntries()
        let dataStore = InMemoryDataStore(entries: testEntries)

        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, testEntries.count, "Should load pre-populated entries")
            XCTAssertEqual(loadedEntries.first?.exerciseName, testEntries.first?.exerciseName)
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    // MARK: - Load Functionality Tests

    func testLoadFromEmptyStore() {
        let dataStore = InMemoryDataStore()
        do {
            let entries = try dataStore.load()
            XCTAssertTrue(entries.isEmpty, "Load from empty store should return empty array")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testLoadAfterSave() {
        let dataStore = InMemoryDataStore()
        let testEntries = createTestEntries()

        XCTAssertNoThrow(try dataStore.save(entries: testEntries))
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, testEntries.count, "Load after save should return saved entries")
            XCTAssertEqual(loadedEntries.first?.exerciseName, testEntries.first?.exerciseName)
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    // MARK: - Save Functionality Tests

    func testSaveEmptyArray() {
        let dataStore = InMemoryDataStore(entries: createTestEntries())
        XCTAssertNoThrow(try dataStore.save(entries: []))
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertTrue(loadedEntries.isEmpty, "Save empty array should clear all entries")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testSaveSingleEntry() {
        let dataStore = InMemoryDataStore()
        let entry = ExerciseEntry(
            exerciseName: "Push-ups",
            date: Date(),
            sets: [ExerciseSet(reps: 10, weight: nil)]
        )

        XCTAssertNoThrow(try dataStore.save(entries: [entry]))
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, 1, "Should save single entry")
            XCTAssertEqual(loadedEntries.first?.exerciseName, "Push-ups")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testSaveMultipleEntries() {
        let dataStore = InMemoryDataStore()
        let testEntries = createTestEntries()

        XCTAssertNoThrow(try dataStore.save(entries: testEntries))
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, testEntries.count, "Should save multiple entries")
            XCTAssertEqual(loadedEntries.first?.exerciseName, testEntries.first?.exerciseName)
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    func testMultipleSaveOperations() {
        let dataStore = InMemoryDataStore()
        let firstEntries = createTestEntries()
        let secondEntries = [
            ExerciseEntry(
                exerciseName: "Squats",
                date: Date(),
                sets: [ExerciseSet(reps: 15, weight: 100.0)]
            )
        ]

        XCTAssertNoThrow(try dataStore.save(entries: firstEntries))
        XCTAssertNoThrow(try dataStore.save(entries: secondEntries))
        do {
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, secondEntries.count, "Second save should replace first")
            XCTAssertEqual(loadedEntries.first?.exerciseName, "Squats")
        } catch {
            XCTFail("Load should not throw error: \(error)")
        }
    }

    // MARK: - Export Functionality Tests

    func testExportEmptyData() {
        let dataStore = InMemoryDataStore()
        do {
            let exportURL = try dataStore.export(entries: [])
            let url = exportURL
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export file should exist")

            guard let data = try? Data(contentsOf: url) else {
                XCTFail("Export file should contain data")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let entries = try? decoder.decode([ExerciseEntry].self, from: data) else {
                XCTFail("Export file should contain valid JSON")
                return
            }
            XCTAssertTrue(entries.isEmpty, "Export file should contain empty array")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Export should not throw error: \(error)")
        }
    }

    func testExportWithData() {
        let dataStore = InMemoryDataStore()
        let testEntries = createTestEntries()

        do {
            let exportURL = try dataStore.export(entries: testEntries)
            let url = exportURL
            guard let data = try? Data(contentsOf: url) else {
                XCTFail("Export file should contain data")
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let entries = try? decoder.decode([ExerciseEntry].self, from: data) else {
                XCTFail("Export file should contain valid JSON")
                return
            }

            XCTAssertEqual(entries.count, testEntries.count, "Export should contain all entries")
            XCTAssertEqual(entries.first?.exerciseName, testEntries.first?.exerciseName)
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Export should not throw error: \(error)")
        }
    }

    func testExportCreatesUniqueFiles() {
        let dataStore = InMemoryDataStore()
        let entry = ExerciseEntry(exerciseName: "Test", date: Date(), sets: [])

        do {
            let url1 = try dataStore.export(entries: [entry])
            let url2 = try dataStore.export(entries: [entry])
            XCTAssertNotEqual(url1.path, url2.path, "Export should create unique files")
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        } catch {
            XCTFail("Export should not throw error: \(error)")
        }
    }

    // MARK: - Protocol Compliance Tests

    func testProtocolComplianceBasicFlow() {
        let dataStore = InMemoryDataStore()
        let testEntries = createTestEntries()

        do {
            let initialEntries = try dataStore.load()
            XCTAssertTrue(initialEntries.isEmpty)

            XCTAssertNoThrow(try dataStore.save(entries: testEntries))

            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, testEntries.count)

            let exportURL = try dataStore.export(entries: loadedEntries)
            try? FileManager.default.removeItem(at: exportURL)
        } catch {
            XCTFail("Protocol compliance workflow should not throw error: \(error)")
        }
    }

    func testDataIntegrityAcrossOperations() {
        let dataStore = InMemoryDataStore()
        let originalEntry = ExerciseEntry(
            exerciseName: "Data Integrity Test",
            date: Date(),
            sets: [
                ExerciseSet(reps: 5, weight: 225.0, notes: "Heavy set"),
                ExerciseSet(reps: 8, weight: 200.0, notes: "Drop set")
            ]
        )

        do {
            XCTAssertNoThrow(try dataStore.save(entries: [originalEntry]))
            let loadedEntries = try dataStore.load()
            let exportURL = try dataStore.export(entries: loadedEntries)

            guard let loadedEntry = loadedEntries.first else {
                XCTFail("Should have loaded entry")
                return
            }
            XCTAssertEqual(loadedEntry.exerciseName, originalEntry.exerciseName)
            XCTAssertEqual(loadedEntry.sets.count, originalEntry.sets.count)
            XCTAssertEqual(loadedEntry.sets.first?.reps, originalEntry.sets.first?.reps)
            XCTAssertEqual(loadedEntry.sets.first?.weight, originalEntry.sets.first?.weight)
            XCTAssertEqual(loadedEntry.sets.first?.notes, originalEntry.sets.first?.notes)

            let url = exportURL
            guard let data = try? Data(contentsOf: url) else {
                XCTFail("Export file should contain data")
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let exportedEntries = try? decoder.decode([ExerciseEntry].self, from: data) else {
                XCTFail("Export file should contain valid JSON")
                return
            }

            XCTAssertEqual(exportedEntries.first?.exerciseName, originalEntry.exerciseName)
            XCTAssertEqual(exportedEntries.first?.sets.count, originalEntry.sets.count)
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Data integrity test should not throw error: \(error)")
        }
    }

    // MARK: - Edge Cases

    func testLargeDataset() {
        let dataStore = InMemoryDataStore()
        let largeDataset = createLargeTestDataset(count: 1000)

        do {
            XCTAssertNoThrow(try dataStore.save(entries: largeDataset))
            let loadedEntries = try dataStore.load()
            XCTAssertEqual(loadedEntries.count, 1000, "Should handle large datasets")
            XCTAssertEqual(loadedEntries.first?.exerciseName, largeDataset.first?.exerciseName)
        } catch {
            XCTFail("Large dataset test should not throw error: \(error)")
        }
    }

    func testSpecialCharactersInData() {
        let dataStore = InMemoryDataStore()
        let specialEntry = ExerciseEntry(
            exerciseName: "Übung with émojis 🏋️‍♂️ and symbols @#$%",
            date: Date(),
            sets: [ExerciseSet(reps: 1, weight: nil, notes: "Special notes: 测试 тест")]
        )

        do {
            XCTAssertNoThrow(try dataStore.save(entries: [specialEntry]))
            let loadedEntries = try dataStore.load()
            let exportURL = try dataStore.export(entries: loadedEntries)

            XCTAssertEqual(loadedEntries.first?.exerciseName, specialEntry.exerciseName)
            XCTAssertEqual(loadedEntries.first?.sets.first?.notes, specialEntry.sets.first?.notes)
            try? FileManager.default.removeItem(at: exportURL)
        } catch {
            XCTFail("Special characters test should not throw error: \(error)")
        }
    }

    func testRapidSaveLoadCycles() {
        let dataStore = InMemoryDataStore()

        do {
            for index in 0..<100 {
                let entries = [ExerciseEntry(
                    exerciseName: "Cycle \(index)",
                    date: Date(),
                    sets: [ExerciseSet(reps: index, weight: Double(index))]
                )]

                XCTAssertNoThrow(try dataStore.save(entries: entries))
                let loaded = try dataStore.load()
                XCTAssertEqual(loaded.count, 1)
                XCTAssertEqual(loaded.first?.exerciseName, "Cycle \(index)")
            }
        } catch {
            XCTFail("Rapid save/load cycles should not throw error: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createTestEntries() -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Push-ups",
                date: Date(),
                sets: [
                    ExerciseSet(reps: 10, weight: nil),
                    ExerciseSet(reps: 8, weight: nil)
                ]
            ),
            ExerciseEntry(
                exerciseName: "Bench Press",
                date: Date(),
                sets: [
                    ExerciseSet(reps: 5, weight: 185.0)
                ]
            )
        ]
    }

    private func createLargeTestDataset(count: Int) -> [ExerciseEntry] {
        (0..<count).map { index in
            ExerciseEntry(
                exerciseName: "Exercise \(index)",
                date: Date().addingTimeInterval(Double(index)),
                sets: [ExerciseSet(reps: index % 20 + 1, weight: Double(index % 300))]
            )
        }
    }
}
