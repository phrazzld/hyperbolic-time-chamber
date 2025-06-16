import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Quick persistence performance tests optimized for CI environments (< 5s execution time)
/// Tests essential save/load operations with small, CI-appropriate dataset sizes
final class QuickPersistencePerformanceTests: XCTestCase {

    let config = TestConfiguration.shared

    private var temporaryDirectory: URL!
    private var dataStore: FileDataStore!
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

            dataStore = FileDataStore(baseDirectory: temporaryDirectory)
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

    // MARK: - Quick Persistence Tests

    func testQuickSavePerformance() {
        let entryCount = config.smallDatasetSize // 20 in CI, 100 locally
        let dataset = generateOptimizedDataset(count: entryCount)

        // Setup: Add entries to ViewModel
        for entry in dataset {
            viewModel.entries.append(entry)
        }

        NSLog("📊 Testing quick save performance with \(entryCount) entries")

        measure {
            viewModel.save()
        }

        // Verify save worked (in real file system)
        if !config.useInMemoryStorage {
            let fileURL = temporaryDirectory.appendingPathComponent("workout_entries.json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Save file should exist")
        }
    }

    func testQuickLoadPerformance() {
        let entryCount = config.smallDatasetSize
        let dataset = generateOptimizedDataset(count: entryCount)

        // Setup: Save dataset first
        for entry in dataset {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, entryCount, "Should have initial entries")

        NSLog("📊 Testing quick load performance with \(entryCount) entries")

        measure {
            // Create fresh ViewModel to test loading
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, entryCount, "Should load all entries")
        }
    }

    func testQuickSaveLoadRoundTrip() {
        let entryCount = config.smallDatasetSize / 2 // Smaller for round-trip test
        let dataset = generateOptimizedDataset(count: entryCount)

        measure {
            // Clear and add entries
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }

            // Save
            viewModel.save()

            // Load in fresh ViewModel
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, entryCount, "Round trip should preserve all entries")
        }
    }

    func testQuickExportPerformance() {
        let entryCount = config.smallDatasetSize / 2 // Smaller for export test
        let dataset = generateOptimizedDataset(count: entryCount)

        // Setup: Add entries
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()

        var exportURL: URL?
        measure {
            exportURL = viewModel.exportJSON()
        }

        XCTAssertNotNil(exportURL, "Export should succeed")

        // Verify export file in real file system
        if !config.useInMemoryStorage, let url = exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export file should exist")
        }
    }

    func testQuickDataIntegrityAfterPersistence() {
        let entryCount = config.smallDatasetSize / 2
        let dataset = generateOptimizedDataset(count: entryCount)

        // Store original IDs for verification
        let originalIds = Set(dataset.map { $0.id })

        measure {
            // Clear any existing data before each iteration
            viewModel.entries.removeAll()

            // Save dataset
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            viewModel.save()

            // Load and verify integrity
            let loadedViewModel = WorkoutViewModel(dataStore: dataStore)
            let loadedIds = Set(loadedViewModel.entries.map { $0.id })

            XCTAssertEqual(originalIds, loadedIds, "All entry IDs should be preserved")
            XCTAssertEqual(loadedViewModel.entries.count, entryCount, "Should load correct count")
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

// MARK: - In-Memory DataStore for CI Optimization

private class InMemoryDataStore: DataStore {
    private var inMemoryEntries: [ExerciseEntry] = []
    private var lastExportData: Data?

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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(entries) else { return nil }
        lastExportData = data

        return URL(fileURLWithPath: "/tmp/mock_export.json")
    }
}
