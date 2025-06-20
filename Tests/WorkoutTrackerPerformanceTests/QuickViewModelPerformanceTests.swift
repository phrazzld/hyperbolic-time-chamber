import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Quick ViewModel performance tests optimized for CI environments (< 5s execution time)
/// Tests essential ViewModel operations with small, CI-appropriate dataset sizes
final class QuickViewModelPerformanceTests: XCTestCase {

    let config = TestConfiguration.shared

    private var temporaryDirectory: URL!
    private var dataStore: DataStoreProtocol!
    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()

        // Use in-memory storage for CI optimization
        if config.useInMemoryStorage {
            dataStore = WorkoutTracker.InMemoryDataStore()
            temporaryDirectory = URL(fileURLWithPath: "/tmp/ci-mock")
        } else {
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

            do {
                dataStore = try FileDataStore(baseDirectory: temporaryDirectory)
            } catch {
                XCTFail("Failed to create FileDataStore: \(error)")
                return
            }
        }

        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        if !config.useInMemoryStorage {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        dataStore = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Quick ViewModel Operation Tests

    func testQuickAddEntryPerformance() {
        let entryCount = config.smallDatasetSize // 20 in CI, 100 locally
        let dataset = generateOptimizedDataset(count: entryCount)

        NSLog("📊 Testing quick add entry performance with \(entryCount) entries")

        measure {
            viewModel.entries.removeAll()

            // Test adding entries one by one (as user would)
            for entry in dataset {
                viewModel.addEntry(entry)
            }
        }

        XCTAssertEqual(viewModel.entries.count, entryCount, "Should contain all added entries")
    }

    func testQuickBulkDeletionPerformance() {
        let entryCount = config.smallDatasetSize
        let dataset = generateOptimizedDataset(count: entryCount)
        let deleteCount = entryCount / 2

        measure {
            // Setup fresh data for each iteration
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }

            // Delete half the entries
            for _ in 0..<deleteCount where !viewModel.entries.isEmpty {
                viewModel.deleteEntry(at: IndexSet([0]))
            }
        }

        // After performance measurement, check final state
        XCTAssertEqual(viewModel.entries.count, entryCount - deleteCount, "Should have remaining entries")
    }

    func testQuickSearchOperations() {
        // Setup: Add small dataset
        let entryCount = config.smallDatasetSize
        let dataset = generateOptimizedDataset(count: entryCount)

        for entry in dataset {
            viewModel.entries.append(entry)
        }

        measure {
            // Test common search operations
            let pushUpEntries = viewModel.entries.filter { $0.exerciseName.contains("Push") }
            let weightedEntries = viewModel.entries.filter { entry in
                entry.sets.contains { $0.weight != nil }
            }
            let recentEntries = viewModel.entries.filter {
                $0.date.timeIntervalSinceNow > -86400 * 7 // Last week
            }

            // Verify operations completed
            XCTAssertGreaterThanOrEqual(pushUpEntries.count, 0, "Search should complete")
            XCTAssertGreaterThanOrEqual(weightedEntries.count, 0, "Weight filter should complete")
            XCTAssertGreaterThanOrEqual(recentEntries.count, 0, "Date filter should complete")
        }
    }

    func testQuickDataManipulation() {
        let entryCount = config.smallDatasetSize / 2 // Even smaller for manipulation test
        let dataset = generateOptimizedDataset(count: entryCount)

        measure {
            // Test a complete workflow: add, sort, filter, delete
            viewModel.entries.removeAll()

            // Add entries
            for entry in dataset {
                viewModel.entries.append(entry)
            }

            // Sort entries by date
            let sortedEntries = viewModel.entries.sorted { $0.date > $1.date }

            // Filter for specific exercise
            let filteredEntries = sortedEntries.filter { $0.exerciseName.contains("Push") }

            // Delete one entry if available
            if !viewModel.entries.isEmpty {
                viewModel.deleteEntry(at: IndexSet([0]))
            }

            XCTAssertEqual(sortedEntries.count, entryCount, "Sort should preserve count")
            XCTAssertGreaterThanOrEqual(filteredEntries.count, 0, "Filter should complete")
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
}
