import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Extreme load stress tests for local development environments only
/// Tests app behavior under extreme conditions to find breaking points and ensure stability
final class ExtremeLoadStressTests: XCTestCase {

    let config = TestConfiguration.shared

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()

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

        dataStore = DataStore(baseDirectory: temporaryDirectory)
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        dataStore = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Extreme Stress Tests

    func testExtremeDatasetStressTest() throws {
        // This test pushes the limits to ensure the app can handle very large datasets
        try TestUtilities.skipIfCI(in: self, reason: "Extreme stress test excluded from CI")

        let entryCount = config.stressDatasetSize // 10,000 locally

        NSLog("📊 Starting extreme dataset stress test with \(entryCount) entries")

        let extremeDataset = generateExtremeDataset(count: entryCount)

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
        XCTAssertLessThan(additionTime, 10.0, "Adding \(entryCount) entries should complete within 10 seconds")

        NSLog("📊 Addition phase completed in \(String(format: "%.2f", additionTime))s")

        // Test save performance
        let saveStartTime = Date()
        viewModel.save()
        saveTime = Date().timeIntervalSince(saveStartTime)

        XCTAssertLessThan(saveTime, 120.0, "Saving \(entryCount) entries should complete within 2 minutes")

        NSLog("📊 Save phase completed in \(String(format: "%.2f", saveTime))s")

        // Test load performance
        let loadStartTime = Date()
        let stressTestViewModel = WorkoutViewModel(dataStore: dataStore)
        loadTime = Date().timeIntervalSince(loadStartTime)

        XCTAssertEqual(stressTestViewModel.entries.count, entryCount, "Should load all \(entryCount) entries")
        XCTAssertLessThan(loadTime, 60.0, "Loading \(entryCount) entries should complete within 1 minute")

        NSLog("📊 Load phase completed in \(String(format: "%.2f", loadTime))s")

        // Test export performance
        let exportStartTime = Date()
        let exportURL = stressTestViewModel.exportJSON()
        let exportTime = Date().timeIntervalSince(exportStartTime)

        XCTAssertNotNil(exportURL, "Should be able to export \(entryCount) entries")
        XCTAssertLessThan(exportTime, 80.0, "Exporting \(entryCount) entries should complete within 80 seconds")

        NSLog("📊 Export phase completed in \(String(format: "%.2f", exportTime))s")

        // Verify export file size
        verifyExportFileSize(exportURL, entryCount: entryCount)
    }

    func testMassiveBulkOperationsStress() throws {
        try TestUtilities.skipIfCI(in: self, reason: "Massive bulk operations stress test excluded from CI")

        let entryCount = config.stressDatasetSize / 2 // 5,000 entries
        let dataset = generateExtremeDataset(count: entryCount)

        NSLog("📊 Testing massive bulk operations with \(entryCount) entries")

        // Setup large dataset
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()

        var operationTimes: [String: TimeInterval] = [:]

        // Perform bulk operations and measure performance
        let operationResults = performBulkOperations(&operationTimes)
        let deleteCount = performBulkDeletion(entryCount: entryCount, operationTimes: &operationTimes)

        // Report performance
        for (operation, time) in operationTimes {
            NSLog("📊 \(operation.capitalized) completed in \(String(format: "%.2f", time))s")
            XCTAssertLessThan(time, 30.0, "\(operation.capitalized) should complete within 30 seconds")
        }

        // Verify operations
        XCTAssertGreaterThanOrEqual(operationResults.filteredCount, 0, "Filtering should complete")
        XCTAssertEqual(operationResults.sortedCount, entryCount, "Sorting should preserve count")
        XCTAssertGreaterThan(operationResults.groupedCount, 0, "Grouping should work")
        XCTAssertEqual(viewModel.entries.count, entryCount - deleteCount, "Deletion should work")
    }

    func testConcurrentOperationsStress() throws {
        try TestUtilities.skipIfCI(in: self, reason: "Concurrent operations stress test excluded from CI")

        let entryCount = config.stressDatasetSize / 4 // 2,500 entries
        let dataset = generateExtremeDataset(count: entryCount)

        NSLog("📊 Testing concurrent operations stress with \(entryCount) entries")

        // Setup dataset
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()

        measure {
            // Simulate multiple heavy operations in sequence
            // (Note: True concurrency would require more complex setup with thread safety)

            // Heavy search operation
            let searchResults = viewModel.entries.filter { entry in
                entry.exerciseName.lowercased().contains("squat") ||
                entry.exerciseName.lowercased().contains("press") ||
                entry.sets.contains { $0.weight != nil && ($0.weight ?? 0) > 150 }
            }

            // Heavy aggregation operation
            let exerciseStats = Dictionary(grouping: viewModel.entries) { $0.exerciseName }
                .mapValues { entries in
                    entries.reduce(0) { sum, entry in
                        sum + entry.sets.reduce(0) { setSum, set in
                            setSum + set.reps
                        }
                    }
                }

            // Export operation
            let exportURL = viewModel.exportJSON()

            // Bulk modification (change exercise names)
            var modifiedCount = 0
            for index in 0..<min(100, viewModel.entries.count) {
                viewModel.entries[index] = ExerciseEntry(
                    exerciseName: "Modified \(viewModel.entries[index].exerciseName)",
                    date: viewModel.entries[index].date,
                    sets: viewModel.entries[index].sets
                )
                modifiedCount += 1
            }

            // Save after modifications
            viewModel.save()

            // Verify operations completed successfully
            XCTAssertGreaterThanOrEqual(searchResults.count, 0, "Search should complete")
            XCTAssertGreaterThan(exerciseStats.count, 0, "Stats aggregation should work")
            XCTAssertNotNil(exportURL, "Export should succeed")
            XCTAssertEqual(modifiedCount, min(100, entryCount), "Modifications should complete")
        }
    }

    func testMemoryExtremeStress() throws {
        try TestUtilities.skipIfCI(in: self, reason: "Memory extreme stress test excluded from CI")

        NSLog("📊 Testing extreme memory stress conditions")

        let phases = [1000, 2500, 5000, 7500, 10000]

        for phase in phases {
            autoreleasepool {
                NSLog("📊 Memory stress phase: \(phase) entries")

                let dataset = generateExtremeDataset(count: phase)

                // Clear previous data
                viewModel.entries.removeAll()

                // Add entries and perform memory-intensive operations
                for entry in dataset {
                    viewModel.entries.append(entry)
                }

                // Memory-intensive operations
                _ = viewModel.entries.sorted { $0.date > $1.date }
                _ = Dictionary(grouping: viewModel.entries) { $0.exerciseName }
                _ = viewModel.entries.filter { entry in
                    entry.sets.contains { $0.weight != nil && ($0.weight ?? 0) > 50 }
                }

                TestUtilities.checkMemoryUsage(operation: "extreme stress phase \(phase)")

                // Clear for next phase
                viewModel.entries.removeAll()
            }
        }

        // Final memory check after all phases
        TestUtilities.checkMemoryUsage(operation: "post-extreme-stress")
    }

    // MARK: - Helper Methods

    private func generateExtremeDataset(count: Int) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Barbell Rows", "Dips", "Lunges", "Planks",
            "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
            "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
            "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls",
            "Arnold Press", "Bulgarian Split Squats", "Romanian Deadlifts",
            "Incline Bench Press", "Decline Bench Press", "Front Squats",
            "Sumo Deadlifts", "Close-Grip Bench Press"
        ]

        let baseDate = Date()

        return (0..<count).map { index in
            let exerciseName = exerciseNames[index % exerciseNames.count]

            // Generate more complex sets for stress testing
            let setCount = Int.random(in: 1...6)
            let sets = (0..<setCount).map { setIndex in
                ExerciseSet(
                    reps: Int.random(in: 1...25),
                    weight: setIndex == 0 ? nil : Double.random(in: 5...300)
                )
            }

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: baseDate.addingTimeInterval(-Double(index) * Double.random(in: 300...7200)), // Random intervals
                sets: sets
            )
        }
    }

    // MARK: - Helper Methods

    private func verifyExportFileSize(_ exportURL: URL?, entryCount: Int) {
        guard let url = exportURL else { return }

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0

            NSLog("📊 Export file size: \(String(format: "%.2f", fileSizeMB))MB")
            XCTAssertGreaterThan(fileSize, 1_000_000, "Export file should be substantial for \(entryCount) entries")
            XCTAssertLessThan(fileSize, 100_000_000, "Export file should not exceed 100MB")
        } catch {
            XCTFail("Failed to check export file attributes: \(error)")
        }
    }

    private struct BulkOperationResults {
        let filteredCount: Int
        let sortedCount: Int
        let groupedCount: Int
    }

    private func performBulkOperations(_ operationTimes: inout [String: TimeInterval]) -> BulkOperationResults {
        // Test massive filtering
        let filterStartTime = Date()
        let filteredEntries = viewModel.entries.filter { entry in
            entry.exerciseName.contains("Press") &&
            entry.sets.count >= 2 &&
            entry.sets.contains { $0.weight != nil && ($0.weight ?? 0) > 100 }
        }
        operationTimes["filtering"] = Date().timeIntervalSince(filterStartTime)

        // Test massive sorting
        let sortStartTime = Date()
        let sortedEntries = viewModel.entries.sorted { first, second in
            if first.exerciseName == second.exerciseName {
                return first.date > second.date
            }
            return first.exerciseName < second.exerciseName
        }
        operationTimes["sorting"] = Date().timeIntervalSince(sortStartTime)

        // Test massive grouping
        let groupStartTime = Date()
        let groupedEntries = Dictionary(grouping: viewModel.entries) { entry in
            "\(entry.exerciseName)-\(Calendar.current.dateInterval(of: .month, for: entry.date)?.start ?? entry.date)"
        }
        operationTimes["grouping"] = Date().timeIntervalSince(groupStartTime)

        return BulkOperationResults(
            filteredCount: filteredEntries.count,
            sortedCount: sortedEntries.count,
            groupedCount: groupedEntries.count
        )
    }

    private func performBulkDeletion(entryCount: Int, operationTimes: inout [String: TimeInterval]) -> Int {
        let deleteStartTime = Date()
        let deleteCount = entryCount / 4
        for _ in 0..<deleteCount where !viewModel.entries.isEmpty {
            viewModel.deleteEntry(at: IndexSet([0]))
        }
        operationTimes["deletion"] = Date().timeIntervalSince(deleteStartTime)
        return deleteCount
    }
}
