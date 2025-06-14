import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Comprehensive memory efficiency tests for local development environments
/// Tests memory usage patterns and efficiency during various operations
final class MemoryEfficiencyTests: PerformanceTestCase {

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

    // MARK: - Memory Efficiency Tests

    func testMemoryUsageWithMediumDataset() throws {
        try skipIfCI(reason: "Memory efficiency test requires controlled environment")

        let entryCount = config.mediumDatasetSize // 500 locally
        let dataset = generateOptimizedDataset(count: entryCount)

        reportProgress("Testing memory usage with \(entryCount) entries")

        measureWithConfig {
            viewModel.entries.removeAll()

            for entry in dataset {
                viewModel.entries.append(entry)
            }

            // Memory-intensive operations
            let filteredEntries = viewModel.entries.filter { $0.exerciseName.contains("Push") }
            let sortedEntries = viewModel.entries.sorted { $0.date > $1.date }
            let groupedEntries = Dictionary(grouping: viewModel.entries) { $0.exerciseName }

            XCTAssertEqual(viewModel.entries.count, entryCount, "Should maintain \(entryCount) entries")
            XCTAssertGreaterThan(filteredEntries.count, 0, "Should find filtered entries")
            XCTAssertEqual(sortedEntries.count, entryCount, "Sorted entries should match original count")
            XCTAssertGreaterThan(groupedEntries.count, 0, "Should group entries")
        }

        checkMemoryUsage(operation: "medium dataset operations")
    }

    func testMemoryEfficiencyAfterBulkOperations() throws {
        try skipIfCI(reason: "Memory efficiency test requires controlled environment")

        let entryCount = config.mediumDatasetSize
        let dataset = generateOptimizedDataset(count: entryCount)

        // Setup: Add dataset
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()

        reportProgress("Testing memory efficiency after bulk operations with \(entryCount) entries")

        measureWithConfig {
            // Bulk deletion
            let deleteCount = entryCount / 2
            let indicesToDelete = Array(deleteCount..<entryCount)

            for index in indicesToDelete.reversed() {
                viewModel.deleteEntry(at: IndexSet([index]))
            }

            // Verify memory doesn't leak after deletion
            let remainingCount = viewModel.entries.count
            XCTAssertEqual(remainingCount, deleteCount, "Should have \(deleteCount) entries after deletion")

            // Perform additional operations to stress memory
            let searchResults = viewModel.entries.filter { $0.exerciseName.contains("Squats") }
            let exportURL = viewModel.exportJSON()

            XCTAssertGreaterThanOrEqual(searchResults.count, 0, "Search should work after deletion")
            XCTAssertNotNil(exportURL, "Export should work after deletion")
        }

        checkMemoryUsage(operation: "post-bulk-deletion")
    }

    func testMemoryLeakPrevention() throws {
        try skipIfCI(reason: "Memory leak test requires controlled environment")

        let entryCount = config.smallDatasetSize * 2

        reportProgress("Testing memory leak prevention with repeated operations")

        measureWithConfig {
            // Perform repeated add/remove cycles to check for leaks
            for cycle in 0..<5 {
                let dataset = generateOptimizedDataset(count: entryCount)

                // Add entries
                viewModel.entries.removeAll()
                for entry in dataset {
                    viewModel.entries.append(entry)
                }

                // Perform operations
                _ = viewModel.entries.filter { $0.exerciseName.contains("Push") }
                _ = viewModel.entries.sorted { $0.date > $1.date }

                // Export operation
                _ = viewModel.exportJSON()

                // Save operation
                viewModel.save()

                // Clear for next cycle
                viewModel.entries.removeAll()

                reportProgress("Completed memory leak test cycle \(cycle + 1)/5")
            }
        }

        checkMemoryUsage(operation: "leak prevention cycles")
    }

    func testLargeDatasetMemoryUsage() throws {
        try skipIfCI(reason: "Large dataset memory test requires controlled environment")

        let entryCount = config.largeDatasetSize // 1000 locally
        let dataset = generateRealisticDataset(count: entryCount)

        reportProgress("Testing memory footprint with large dataset (\(entryCount) entries)")

        measureWithConfig {
            autoreleasepool {
                viewModel.entries.removeAll()

                // Add entries gradually and measure memory pressure
                for (index, entry) in dataset.enumerated() {
                    viewModel.entries.append(entry)

                    // Check memory at milestones
                    if index % 200 == 0 && index > 0 {
                        checkMemoryUsage(operation: "loading \(index) entries")
                    }
                }

                // Final memory check
                checkMemoryUsage(operation: "final large dataset")

                // Test complex operations on large dataset
                let complexFilter = viewModel.entries.filter { entry in
                    entry.exerciseName.contains("Press") &&
                    entry.sets.count >= 3 &&
                    entry.sets.contains { $0.weight != nil && ($0.weight ?? 0) > 50 }
                }

                let sortedByDate = viewModel.entries.sorted { $0.date > $1.date }
                let groupedByExercise = Dictionary(grouping: viewModel.entries) { $0.exerciseName }

                XCTAssertGreaterThanOrEqual(complexFilter.count, 0, "Complex filter should complete")
                XCTAssertEqual(sortedByDate.count, entryCount, "Sort should preserve count")
                XCTAssertGreaterThan(groupedByExercise.count, 0, "Grouping should work")
            }
        }
    }

    func testMemoryRecoveryAfterLargeOperations() throws {
        try skipIfCI(reason: "Memory recovery test requires controlled environment")

        let entryCount = config.largeDatasetSize

        reportProgress("Testing memory recovery after large operations")

        measureWithConfig {
            autoreleasepool {
                // Create and process large dataset
                let dataset = generateRealisticDataset(count: entryCount)

                viewModel.entries.removeAll()
                for entry in dataset {
                    viewModel.entries.append(entry)
                }

                // Memory-intensive operations
                _ = viewModel.entries.sorted { $0.date > $1.date }
                _ = Dictionary(grouping: viewModel.entries) { $0.exerciseName }
                _ = viewModel.exportJSON()

                checkMemoryUsage(operation: "after large operations")
            }

            // Clear everything and check memory recovery
            viewModel.entries.removeAll()

            // Small operation to verify memory has been freed
            let smallDataset = generateOptimizedDataset(count: 10)
            for entry in smallDataset {
                viewModel.entries.append(entry)
            }

            checkMemoryUsage(operation: "after memory recovery")
        }
    }

    // MARK: - Helper Methods

    private func generateOptimizedDataset(count: Int) -> [ExerciseEntry] {
        let exerciseNames = ["Push-ups", "Squats", "Pull-ups", "Planks", "Burpees"]
        let baseDate = Date(timeIntervalSince1970: 1000000)

        return (0..<count).map { index in
            ExerciseEntry(
                exerciseName: exerciseNames[index % exerciseNames.count],
                date: baseDate.addingTimeInterval(-Double(index) * 3600),
                sets: [ExerciseSet(reps: 10, weight: index % 2 == 0 ? nil : 50.0)]
            )
        }
    }

    private func generateRealisticDataset(count: Int) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Rows", "Dips", "Lunges", "Planks"
        ]

        let baseDate = Date()

        return (0..<count).map { index in
            let exerciseName = exerciseNames[index % exerciseNames.count]

            let setCount = Int.random(in: 1...4)
            let sets = (0..<setCount).map { setIndex in
                ExerciseSet(
                    reps: Int.random(in: 5...15),
                    weight: setIndex == 0 ? nil : Double.random(in: 20...150)
                )
            }

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: baseDate.addingTimeInterval(-Double(index) * 3600),
                sets: sets
            )
        }
    }
}
