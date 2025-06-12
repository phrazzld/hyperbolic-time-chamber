// swiftlint:disable file_length
import XCTest
import Foundation
@testable import WorkoutTracker

// swiftlint:disable:next orphaned_doc_comment
/// Performance tests for large workout datasets (1000+ entries)
/// Tests app performance, memory usage, and scalability with substantial data loads
// swiftlint:disable:next type_body_length
final class LargeDatasetPerformanceTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    // MARK: - CI Environment Detection

    /// Detects if tests are running in a CI environment using multiple indicators
    /// Primarily uses GITHUB_ACTIONS but includes fallbacks for robustness
    private var isRunningInCI: Bool {
        let environment = ProcessInfo.processInfo.environment

        // Primary detection: GitHub Actions
        if environment["GITHUB_ACTIONS"] == "true" {
            NSLog("🔍 CI detected via GITHUB_ACTIONS=true")
            return true
        }

        // Fallback detection methods for comprehensive CI identification
        let ciIndicators = [
            "CI",           // Generic CI indicator
            "CONTINUOUS_INTEGRATION",  // Another common CI variable
            "BUILD_NUMBER", // Jenkins and others
            "TRAVIS",       // Travis CI
            "CIRCLECI",     // Circle CI
            "BUILDKITE"     // Buildkite
        ]

        for indicator in ciIndicators where environment[indicator] != nil {
            NSLog("🔍 CI detected via fallback indicator: \(indicator)")
            return true
        }

        NSLog("🏠 Local development environment detected")
        return false
    }

    override func setUp() {
        super.setUp()

        // Create isolated temporary directory for each test
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        // Create DataStore with temporary directory to avoid conflicts
        dataStore = DataStore(baseDirectory: temporaryDirectory)
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        dataStore = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Test Data Generation

    /// Generates realistic workout entries for performance testing
    private func generateLargeDataset(entryCount: Int) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Rows", "Dips", "Lunges", "Planks",
            "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
            "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
            "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls",
            "Arnold Press", "Bulgarian Split Squats", "Romanian Deadlifts"
        ]

        return (0..<entryCount).map { entryIndex in
            let exerciseName = exerciseNames[entryIndex % exerciseNames.count]
            let setsCount = (entryIndex % 5) + 1 // 1-5 sets per exercise

            let sets = (0..<setsCount).map { setIndex in
                let reps = 8 + (setIndex * 2) + (entryIndex % 5) // Varied reps: 8-20
                // Mix of bodyweight and weighted exercises
                let weight = entryIndex % 3 == 0 ? nil : Double(40 + (entryIndex % 60))
                return ExerciseSet(reps: reps, weight: weight)
            }

            return ExerciseEntry(
                exerciseName: "\(exerciseName) \(entryIndex / exerciseNames.count + 1)",
                date: Date().addingTimeInterval(-Double(entryIndex * 3600)), // 1 hour ago, going backwards
                sets: sets
            )
        }
    }

    // MARK: - Dataset Creation Performance Tests

    func testLargeDatasetCreationPerformance() {
        measure {
            // Use smaller dataset in CI to avoid timeouts
            let entryCount = isRunningInCI ? 500 : 1000
            let largeDataset = generateLargeDataset(entryCount: entryCount)
            XCTAssertEqual(largeDataset.count, entryCount, "Should generate exactly \(entryCount) entries")
        }
    }

    func testExtraLargeDatasetCreationPerformance() {
        measure {
            // Use smaller dataset in CI to avoid timeouts
            let entryCount = isRunningInCI ? 1000 : 5000
            let extraLargeDataset = generateLargeDataset(entryCount: entryCount)
            XCTAssertEqual(extraLargeDataset.count, entryCount, "Should generate exactly \(entryCount) entries")
        }
    }

    // MARK: - ViewModel Operations Performance Tests

    func testAddingLargeDatasetToViewModelPerformance() {
        let dataset = generateLargeDataset(entryCount: 100) // Reduce size for performance test

        measure {
            // Clear any existing entries
            viewModel.entries.removeAll()

            // Add all entries (this triggers save operations)
            for entry in dataset {
                viewModel.addEntry(entry)
            }
        }

        XCTAssertEqual(viewModel.entries.count, 100, "ViewModel should contain all 100 entries")
    }

    func testBulkDeletionPerformance() {
        // Arrange: Add dataset first (optimized size for performance testing)
        let dataset = generateLargeDataset(entryCount: 200)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions
        XCTAssertEqual(viewModel.entries.count, 200, "Should have 200 entries initially")

        // Act & Measure: Delete half the entries (second half)
        measure {
            // Delete entries 100-199 (second half of 200 entries)
            let indicesToDelete = Array(100..<200)
            for index in indicesToDelete.reversed() { // Delete from end to maintain indices
                viewModel.deleteEntry(at: IndexSet([index]))
            }
        }

        XCTAssertEqual(viewModel.entries.count, 100, "Should have 100 entries remaining after deleting second half")
    }

    func testViewModelSearchOperationsPerformance() {
        // Arrange: Add dataset (optimized size for performance testing)
        let dataset = generateLargeDataset(entryCount: 500)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions

        measure {
            // Simulate common search operations
            let pushUpEntries = viewModel.entries.filter { $0.exerciseName.contains("Push-ups") }
            let weightedEntries = viewModel.entries.filter { entry in
                entry.sets.contains { $0.weight != nil }
            }
            let recentEntries = viewModel.entries.filter {
                $0.date.timeIntervalSinceNow > -86400 * 30 // Last 30 days
            }

            // Verify operations found expected results
            XCTAssertGreaterThan(pushUpEntries.count, 0, "Should find push-up entries")
            XCTAssertGreaterThan(weightedEntries.count, 0, "Should find weighted entries")
            XCTAssertGreaterThan(recentEntries.count, 0, "Should find recent entries")
        }
    }

    // MARK: - Data Persistence Performance Tests

    func testLargeDatasetSavePerformance() {
        let dataset = generateLargeDataset(entryCount: 1500)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        measure {
            viewModel.save()
        }
        let fileURL = temporaryDirectory.appendingPathComponent("workout_entries.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Save file should exist")
    }

    func testLargeDatasetLoadPerformance() {
        let dataset = generateLargeDataset(entryCount: 2000)
        for entry in dataset {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, 2000, "Should have saved 2000 entries")
        measure {
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, 2000, "Should load all 2000 entries")
        }
    }

    func testSaveLoadRoundTripPerformance() {
        let dataset = generateLargeDataset(entryCount: 1000)
        measure {
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            viewModel.save()
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, 1000, "Round trip should preserve all entries")
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageWithLargeDataset() {
        measure {
            viewModel.entries.removeAll()
            let dataset = generateLargeDataset(entryCount: 800)
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            let filteredEntries = viewModel.entries.filter { $0.exerciseName.contains("Push") }
            let sortedEntries = viewModel.entries.sorted { $0.date > $1.date }
            XCTAssertEqual(viewModel.entries.count, 800, "Should maintain 800 entries")
            XCTAssertGreaterThan(filteredEntries.count, 0, "Should find filtered entries")
            XCTAssertEqual(sortedEntries.count, 800, "Sorted entries should match original count")
        }
    }

    func testMemoryEfficiencyAfterBulkOperations() {
        // Use smaller dataset in CI to avoid timeouts
        let entryCount = isRunningInCI ? 100 : 400
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        measure {
            let deleteCount = entryCount / 2
            let indicesToDelete = Array(deleteCount..<entryCount)
            for index in indicesToDelete.reversed() {
                viewModel.deleteEntry(at: IndexSet([index]))
            }
            XCTAssertEqual(viewModel.entries.count, deleteCount, "Should have \(deleteCount) entries after deletion")
        }
    }

    // MARK: - Export Performance Tests

    func testLargeDatasetExportPerformance() {
        let dataset = generateLargeDataset(entryCount: 600)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        var exportURL: URL?
        measure {
            exportURL = viewModel.exportJSON()
        }
        XCTAssertNotNil(exportURL, "Export should succeed")
        if let url = exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export file should exist")
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                XCTAssertGreaterThan(fileSize, 20_000, "Export file should be substantial for 600 entries")
                XCTAssertLessThan(fileSize, 10_000_000, "Export file should not be excessively large")
            } catch {
                XCTFail("Failed to check export file attributes: \(error)")
            }
        }
    }

    func testExportDataIntegrityWithLargeDataset() {
        let dataset = generateLargeDataset(entryCount: 300)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        var exportURL: URL?
        var exportedEntries: [ExerciseEntry] = []
        measure {
            exportURL = viewModel.exportJSON()
            if let url = exportURL {
                do {
                    let exportData = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    exportedEntries = try decoder.decode([ExerciseEntry].self, from: exportData)
                } catch {
                    XCTFail("Failed to decode exported data: \(error)")
                }
            }
        }
        XCTAssertEqual(exportedEntries.count, 300, "Exported data should contain all entries")
        let originalIds = Set(viewModel.entries.map { $0.id })
        let exportedIds = Set(exportedEntries.map { $0.id })
        XCTAssertEqual(originalIds, exportedIds, "All entry IDs should be preserved in export")
    }

    // MARK: - Scalability Tests

    func testScalabilityAcrossDifferentDatasetSizes() {
        let sizes = [1000, 2500, 5000]
        var addTimes: [Double] = []
        var saveTimes: [Double] = []

        for size in sizes {
            let dataset = generateLargeDataset(entryCount: size)

            // Clear previous data
            viewModel.entries.removeAll()

            // Measure add time
            let addStartTime = Date()
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            let addTime = Date().timeIntervalSince(addStartTime)
            addTimes.append(addTime)

            // Measure save time
            let saveStartTime = Date()
            viewModel.save()
            let saveTime = Date().timeIntervalSince(saveStartTime)
            saveTimes.append(saveTime)
        }

        // Verify scalability - performance should not degrade exponentially
        // Allow more flexibility since file I/O can be variable and CI environments have performance variations
        XCTAssertLessThan(addTimes[1] / addTimes[0], 12.0, "2.5x data should not take >12x time to add")
        XCTAssertLessThan(addTimes[2] / addTimes[0], 30.0, "5x data should not take >30x time to add")

        XCTAssertLessThan(saveTimes[1] / saveTimes[0], 12.0, "2.5x data should not take >12x time to save")
        XCTAssertLessThan(saveTimes[2] / saveTimes[0], 30.0, "5x data should not take >30x time to save")
    }

    func testConcurrentOperationsPerformance() {
        let dataset = generateLargeDataset(entryCount: 300)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions

        measure {
            // Simulate multiple operations happening in sequence
            // (actual concurrency would require more complex setup)

            // Search operation
            let searchResults = viewModel.entries.filter { $0.exerciseName.contains("Squats") }

            // Export operation
            let exportURL = viewModel.exportJSON()

            let countBeforeDeletion = viewModel.entries.count

            // Deletion operation (delete 3 entries at once)
            viewModel.deleteEntry(at: IndexSet([0, 1, 2]))

            let countAfterDeletion = viewModel.entries.count

            // Addition operation
            let newEntry = ExerciseEntry(
                exerciseName: "Concurrent Test Exercise",
                date: Date(),
                sets: [ExerciseSet(reps: 10, weight: 50.0)]
            )
            viewModel.addEntry(newEntry)

            let finalCount = viewModel.entries.count

            // Verify operations completed successfully
            XCTAssertGreaterThan(searchResults.count, 0, "Search should find results")
            XCTAssertNotNil(exportURL, "Export should succeed")
            XCTAssertEqual(countAfterDeletion, countBeforeDeletion - 3, "Should delete exactly 3 entries")
            XCTAssertEqual(finalCount, countAfterDeletion + 1, "Should add exactly 1 entry")
        }
    }

    // MARK: - Stress Tests

    func testExtremeDatasetStressTest() {
        // This test pushes the limits to ensure the app can handle very large datasets
        // Use smaller dataset in CI to avoid timeouts
        let entryCount = isRunningInCI ? 2000 : 10000
        let extremeDataset = generateLargeDataset(entryCount: entryCount)

        var additionTime: TimeInterval = 0
        var saveTime: TimeInterval = 0
        var loadTime: TimeInterval = 0

        // Test addition performance
        let addStartTime = Date()
        for entry in extremeDataset {
            viewModel.entries.append(entry)
        }
        additionTime = Date().timeIntervalSince(addStartTime)
        XCTAssertEqual(viewModel.entries.count, entryCount, "Should handle \(entryCount) entries")
        XCTAssertLessThan(additionTime, 5.0, "Adding \(entryCount) entries should complete within 5 seconds")

        // Test save performance
        let saveStartTime = Date()
        viewModel.save()
        saveTime = Date().timeIntervalSince(saveStartTime)
        XCTAssertLessThan(saveTime, 60.0, "Saving \(entryCount) entries should complete within 60 seconds")

        // Test load performance
        let loadStartTime = Date()
        let stressTestViewModel = WorkoutViewModel(dataStore: dataStore)
        loadTime = Date().timeIntervalSince(loadStartTime)
        XCTAssertEqual(stressTestViewModel.entries.count, entryCount, "Should load all \(entryCount) entries")
        XCTAssertLessThan(loadTime, 30.0, "Loading \(entryCount) entries should complete within 30 seconds")

        // Test export performance
        let exportStartTime = Date()
        let exportURL = stressTestViewModel.exportJSON()
        let exportTime = Date().timeIntervalSince(exportStartTime)

        XCTAssertNotNil(exportURL, "Should be able to export \(entryCount) entries")
        XCTAssertLessThan(exportTime, 40.0, "Exporting \(entryCount) entries should complete within 40 seconds")
    }
}
