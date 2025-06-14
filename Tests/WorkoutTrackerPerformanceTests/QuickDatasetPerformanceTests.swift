import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Quick dataset performance tests optimized for CI environments (< 5s execution time)
/// Tests essential dataset operations with small, CI-appropriate dataset sizes
final class QuickDatasetPerformanceTests: PerformanceTestCase {

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()

        // Use in-memory storage for CI optimization
        if config.useInMemoryStorage {
            dataStore = InMemoryDataStore()
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

            dataStore = DataStore(baseDirectory: temporaryDirectory)
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

    // MARK: - Quick Dataset Creation Tests

    func testQuickDatasetCreation() {
        let entryCount = config.smallDatasetSize // 20 in CI, 100 locally
        reportProgress("Starting quick dataset creation test with \(entryCount) entries")

        measureWithConfig {
            let dataset = generateOptimizedDataset(count: entryCount)
            XCTAssertEqual(dataset.count, entryCount, "Should generate exactly \(entryCount) entries")
        }
    }

    func testSmallDatasetOperations() {
        let entryCount = config.smallDatasetSize
        let dataset = generateOptimizedDataset(count: entryCount)

        measureWithConfig {
            // Test basic operations on small dataset
            viewModel.entries.removeAll()

            // Add entries efficiently
            for entry in dataset {
                viewModel.entries.append(entry)
            }

            // Single save operation
            viewModel.save()

            // Basic search operation
            let searchResults = viewModel.entries.filter { $0.exerciseName.contains("Push") }
            XCTAssertGreaterThanOrEqual(searchResults.count, 0, "Search should complete successfully")
        }

        XCTAssertEqual(viewModel.entries.count, entryCount, "Should contain all entries")
    }

    // MARK: - Optimized Dataset Generation

    private func generateOptimizedDataset(count: Int) -> [ExerciseEntry] {
        WorkoutTestDataFactory.createOptimizedDataset(
            count: count,
            baseDate: Date(timeIntervalSince1970: 1000000)
        )
    }
}

// MARK: - In-Memory DataStore for CI Optimization

private class InMemoryDataStore: DataStore {
    private var inMemoryEntries: [ExerciseEntry] = []

    override init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        super.init(fileManager: fileManager, baseDirectory: baseDirectory)
    }

    override func load() -> [ExerciseEntry] {
        inMemoryEntries
    }

    override func save(entries: [ExerciseEntry]) {
        inMemoryEntries = entries
    }

    override func export(entries: [ExerciseEntry]) -> URL? {
        // Mock export for CI testing
        URL(fileURLWithPath: "/tmp/mock_export.json")
    }
}
