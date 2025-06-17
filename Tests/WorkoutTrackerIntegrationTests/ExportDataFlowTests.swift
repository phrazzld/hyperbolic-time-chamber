import XCTest
import Foundation
import Combine
@testable import WorkoutTracker

/// Comprehensive tests for the "Export workout data" complete user flow
final class ExportDataFlowTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var testDataStore: FileDataStore!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory,
                                                withIntermediateDirectories: true)
        do {
            testDataStore = try FileDataStore(baseDirectory: tempDirectory)
        } catch {
            XCTFail("Failed to create FileDataStore: \(error)")
            return
        }
        viewModel = WorkoutViewModel(dataStore: testDataStore)
    }

    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        viewModel = nil
        testDataStore = nil
        tempDirectory = nil
    }

    // MARK: - Basic Export Flow Tests

    func testExportEmptyAndSingleEntryFlow() throws {
        // Test empty export
        guard let emptyExportURL = viewModel.exportJSON() else {
            XCTFail("Export should return URL for empty data")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: emptyExportURL.path))

        let emptyData = try Data(contentsOf: emptyExportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let emptyEntries = try decoder.decode([ExerciseEntry].self, from: emptyData)
        XCTAssertTrue(emptyEntries.isEmpty)

        // Test single entry export
        let entry = ExerciseEntry(exerciseName: "Test Workout", date: Date(), sets: [
            ExerciseSet(reps: 10, weight: 50.0, notes: "Test set")
        ])
        viewModel.addEntry(entry)

        guard let singleExportURL = viewModel.exportJSON() else {
            XCTFail("Export should return URL for single entry")
            return
        }

        let singleData = try Data(contentsOf: singleExportURL)
        let singleEntries = try decoder.decode([ExerciseEntry].self, from: singleData)
        XCTAssertEqual(singleEntries.count, 1)
        XCTAssertEqual(singleEntries.first?.exerciseName, "Test Workout")
        XCTAssertEqual(viewModel.entries.count, 1) // Original data unchanged
    }

    func testExportMultipleEntriesWithVariedData() throws {
        let entries = createVariedWorkoutEntries()
        for entry in entries {
            viewModel.addEntry(entry)
        }

        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should succeed")
            return
        }

        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        XCTAssertEqual(decodedEntries.count, 3)
        let exerciseNames = decodedEntries.map { $0.exerciseName }
        XCTAssertTrue(exerciseNames.contains("Push-ups"))
        XCTAssertTrue(exerciseNames.contains("Squats"))
        XCTAssertTrue(exerciseNames.contains("Deadlifts"))

        // Verify complex entry data integrity
        let deadliftsEntry = decodedEntries.first { $0.exerciseName == "Deadlifts" }
        XCTAssertEqual(deadliftsEntry?.sets.count, 3)
        XCTAssertEqual(deadliftsEntry?.sets.last?.weight, 200.0)
    }

    func testExportWithSpecialCharactersAndEdgeCases() throws {
        let specialEntries = [
            ExerciseEntry(exerciseName: "🏋️‍♂️ Olympic", date: Date(), sets: [
                ExerciseSet(reps: 5, weight: 100.0, notes: "💪 Strong! 🔥")
            ]),
            ExerciseEntry(exerciseName: "Силовая тренировка", date: Date(), sets: [
                ExerciseSet(reps: 10, weight: 80.0, notes: "Отлично")
            ]),
            ExerciseEntry(exerciseName: "", date: Date(), sets: [
                ExerciseSet(reps: 0, weight: nil, notes: nil)
            ]),
            ExerciseEntry(exerciseName: "Precision", date: Date(), sets: [
                ExerciseSet(reps: 999, weight: 123.456789, notes: String(repeating: "A", count: 100))
            ])
        ]

        for entry in specialEntries {
            viewModel.addEntry(entry)
        }

        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should handle special characters and edge cases")
            return
        }

        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        XCTAssertEqual(decodedEntries.count, 4)

        // Verify special characters preserved
        let emojiEntry = decodedEntries.first { $0.exerciseName.contains("🏋️‍♂️") }
        XCTAssertEqual(emojiEntry?.sets.first?.notes, "💪 Strong! 🔥")

        let cyrillicEntry = decodedEntries.first { $0.exerciseName == "Силовая тренировка" }
        XCTAssertEqual(cyrillicEntry?.sets.first?.notes, "Отлично")

        // Verify edge cases
        let emptyEntry = decodedEntries.first { $0.exerciseName.isEmpty }
        XCTAssertNil(emptyEntry?.sets.first?.weight)
        XCTAssertNil(emptyEntry?.sets.first?.notes)

        let precisionEntry = decodedEntries.first { $0.exerciseName == "Precision" }
        XCTAssertEqual(precisionEntry?.sets.first?.weight ?? 0.0, 123.456789, accuracy: 0.000001)
    }

    func testExportFileManagementAndOverwrite() throws {
        // Test file overwrite behavior and permissions
        let firstEntry = ExerciseEntry(exerciseName: "First", date: Date(), sets: [
            ExerciseSet(reps: 10, weight: 50.0, notes: "First")
        ])
        viewModel.addEntry(firstEntry)

        guard let firstURL = viewModel.exportJSON() else {
            XCTFail("First export should succeed")
            return
        }

        // Verify file properties
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: firstURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: firstURL.path)
        let firstSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(firstSize, 0)

        // Add more data and re-export
        let secondEntry = ExerciseEntry(exerciseName: "Second", date: Date(), sets: [
            ExerciseSet(reps: 8, weight: 60.0, notes: "Second")
        ])
        viewModel.addEntry(secondEntry)

        guard let secondURL = viewModel.exportJSON() else {
            XCTFail("Second export should succeed")
            return
        }

        // Verify same file location but updated content
        XCTAssertEqual(firstURL.path, secondURL.path)

        let newAttributes = try FileManager.default.attributesOfItem(atPath: secondURL.path)
        let secondSize = newAttributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(secondSize, firstSize, "File should be larger with more data")

        // Verify content was overwritten
        let exportData = try Data(contentsOf: secondURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([ExerciseEntry].self, from: exportData)
        XCTAssertEqual(entries.count, 2)
    }

    func testExportDatePrecisionAndJSONFormat() throws {
        let referenceDate = Date()
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: referenceDate) else {
            XCTFail("Failed to create test date")
            return
        }

        let entry = ExerciseEntry(exerciseName: "Date Test", date: pastDate, sets: [
            ExerciseSet(reps: 10, weight: 50.0, notes: "Testing dates")
        ])
        viewModel.addEntry(entry)

        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should succeed")
            return
        }

        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        // Verify date precision
        guard let decodedEntry = decodedEntries.first else {
            XCTFail("Should have decoded entry")
            return
        }
        XCTAssertEqual(decodedEntry.date.timeIntervalSince1970,
                       pastDate.timeIntervalSince1970,
                       accuracy: 1.0)

        // Verify JSON format
        let jsonString = String(data: exportData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("T") == true, "Should contain ISO8601 time separator")
        XCTAssertTrue(jsonString?.contains("Z") == true, "Should contain UTC timezone")
    }

    func testCompleteExportImportWorkflow() throws {
        // Test complete user workflow: Add -> Export -> Clear -> Import -> Verify
        let originalEntries = createVariedWorkoutEntries()
        for entry in originalEntries {
            viewModel.addEntry(entry)
        }
        let originalCount = viewModel.entries.count

        // Export data
        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should succeed")
            return
        }

        // Clear all data
        for _ in 0..<originalCount {
            viewModel.deleteEntry(at: IndexSet([0]))
        }
        XCTAssertTrue(viewModel.entries.isEmpty)

        // Import from export
        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        for entry in importedEntries {
            viewModel.addEntry(entry)
        }

        // Verify restoration
        XCTAssertEqual(viewModel.entries.count, originalCount)
        let restoredNames = viewModel.entries.map { $0.exerciseName }
        let originalNames = originalEntries.map { $0.exerciseName }
        for name in originalNames {
            XCTAssertTrue(restoredNames.contains(name), "Should restore \(name)")
        }
    }

    func testExportDoesNotModifyOriginalDataAndPersistence() throws {
        let entries = createVariedWorkoutEntries()
        for entry in entries {
            viewModel.addEntry(entry)
        }

        let originalCount = viewModel.entries.count
        let originalNames = viewModel.entries.map { $0.exerciseName }

        // Perform multiple exports
        for _ in 0..<3 {
            XCTAssertNotNil(viewModel.exportJSON(), "Export should succeed multiple times")
        }

        // Verify original data unchanged
        XCTAssertEqual(viewModel.entries.count, originalCount)
        XCTAssertEqual(viewModel.entries.map { $0.exerciseName }, originalNames)

        // Verify persistence unaffected
        let newViewModel = WorkoutViewModel(dataStore: testDataStore)
        XCTAssertEqual(newViewModel.entries.count, originalCount)
    }

    func testExportLargeDatasetPerformance() throws {
        let largeDataset = createLargeWorkoutDataset(entryCount: 50)
        for entry in largeDataset {
            viewModel.addEntry(entry)
        }

        let startTime = Date()
        guard let exportURL = viewModel.exportJSON() else {
            XCTFail("Export should handle large datasets")
            return
        }
        let exportTime = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(exportTime, 3.0, "Export should be reasonably fast")

        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)

        XCTAssertEqual(decodedEntries.count, 50)

        let attributes = try FileManager.default.attributesOfItem(atPath: exportURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000)
    }

    // MARK: - Helper Methods

    private func createVariedWorkoutEntries() -> [ExerciseEntry] {
        let baseDate = Date()
        guard let date1 = Calendar.current.date(byAdding: .day, value: -2, to: baseDate),
              let date2 = Calendar.current.date(byAdding: .day, value: -1, to: baseDate) else {
            return []
        }

        return [
            ExerciseEntry(exerciseName: "Push-ups", date: date1, sets: [
                ExerciseSet(reps: 20, weight: nil, notes: "Body weight")
            ]),
            ExerciseEntry(exerciseName: "Squats", date: date2, sets: [
                ExerciseSet(reps: 15, weight: 50.0, notes: "Light"),
                ExerciseSet(reps: 12, weight: 60.0, notes: "Medium")
            ]),
            ExerciseEntry(exerciseName: "Deadlifts", date: baseDate, sets: [
                ExerciseSet(reps: 8, weight: 100.0, notes: "Warmup"),
                ExerciseSet(reps: 5, weight: 150.0, notes: "Working"),
                ExerciseSet(reps: 3, weight: 200.0, notes: "Heavy")
            ])
        ]
    }

    private func createLargeWorkoutDataset(entryCount: Int) -> [ExerciseEntry] {
        var entries: [ExerciseEntry] = []
        let baseDate = Date()

        for index in 0..<entryCount {
            guard let entryDate = Calendar.current.date(byAdding: .day, value: -index, to: baseDate) else {
                continue
            }

            let sets = [ExerciseSet(reps: 10 + index % 5, weight: Double(50 + index), notes: "Set \(index)")]
            let entry = ExerciseEntry(exerciseName: "Workout \(index + 1)", date: entryDate, sets: sets)
            entries.append(entry)
        }

        return entries
    }
}
