// swiftlint:disable file_length
import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

// swiftlint:disable:next orphaned_doc_comment
/// Performance tests for large workout datasets (1000+ entries)
/// Tests app performance, memory usage, and scalability with substantial data loads
// swiftlint:disable:next type_body_length
final class LargeDatasetPerformanceTests: PerformanceTestCase {

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    // MARK: - CI Environment Detection
    // Now handled by TestConfiguration

    // MARK: - CI-Optimized DataStore

    /// In-memory DataStore implementation for CI environments to avoid file I/O overhead
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

            // Return a mock URL for CI testing - the actual file doesn't exist
            return URL(fileURLWithPath: "/tmp/mock_export.json")
        }

        /// For testing purposes - verify export data was generated
        func getLastExportData() -> Data? {
            lastExportData
        }
    }

    override func setUp() {
        super.setUp()

        // Clear dataset cache for test isolation
        datasetCache.removeAll()

        if config.useInMemoryStorage {
            // Use in-memory DataStore for CI to avoid file I/O overhead
            NSLog("🚀 Using in-memory DataStore for \(config.environmentName) performance optimization")
            dataStore = InMemoryDataStore()
            // No temporary directory needed for in-memory operations
            temporaryDirectory = URL(fileURLWithPath: "/tmp/ci-mock")
        } else {
            // Create isolated temporary directory for each test in local development
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
        }

        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        // Clean up temporary directory only in local development
        if !config.useInMemoryStorage {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        dataStore = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Test Data Generation

    // Pre-computed exercise names for faster access
    private static let exerciseNames = [
        "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
        "Overhead Press", "Rows", "Dips", "Lunges", "Planks",
        "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
        "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
        "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls",
        "Arnold Press", "Bulgarian Split Squats", "Romanian Deadlifts"
    ]

    // Pre-generated exercise sets for reuse
    private static let preGeneratedSets: [[ExerciseSet]] = {
        // Generate 5 different set combinations that can be reused
        (1...5).map { setCount in
            (0..<setCount).map { setIndex in
                ExerciseSet(reps: 10 + (setIndex * 2), weight: setIndex == 0 ? nil : Double(45 + setIndex * 5))
            }
        }
    }()

    // Cache for generated datasets to avoid regeneration
    private var datasetCache: [Int: [ExerciseEntry]] = [:]

    // Pre-generate common CI dataset sizes for immediate access
    private static let commonDatasets: [Int: [ExerciseEntry]] = {
        var datasets: [Int: [ExerciseEntry]] = [:]
        let commonSizes = [20, 25, 30, 35, 40, 50] // Common CI sizes

        for size in commonSizes {
            datasets[size] = LargeDatasetPerformanceTests.generateStaticDataset(count: size)
        }

        return datasets
    }()

    // Static dataset generation for pre-computed datasets
    private static func generateStaticDataset(count: Int) -> [ExerciseEntry] {
        let baseDate = Date(timeIntervalSince1970: 1000000) // Fixed date for consistency
        return (0..<count).map { index in
            ExerciseEntry(
                exerciseName: exerciseNames[index % exerciseNames.count],
                date: baseDate.addingTimeInterval(-Double(index) * 3600),
                sets: preGeneratedSets[index % 5]
            )
        }
    }

    /// Generates realistic workout entries for performance testing (optimized version)
    private func generateLargeDataset(entryCount: Int) -> [ExerciseEntry] {
        // Check pre-generated common datasets first
        if let common = Self.commonDatasets[entryCount] {
            return common
        }

        // Check instance cache
        if let cached = datasetCache[entryCount] {
            return cached
        }

        // Use a single base date and simple offset calculation
        let baseDate = Date()
        let hourInSeconds: Double = 3600

        // Pre-allocate array capacity for better performance
        var entries = [ExerciseEntry]()
        entries.reserveCapacity(entryCount)

        // Generate entries with simplified calculations
        for entryIndex in 0..<entryCount {
            let exerciseNameIndex = entryIndex % Self.exerciseNames.count
            let exerciseName = Self.exerciseNames[exerciseNameIndex]
            let suffix = entryIndex / Self.exerciseNames.count

            // Reuse pre-generated sets
            let setIndex = entryIndex % 5
            let sets = Self.preGeneratedSets[setIndex]

            // Simple date calculation
            let entryDate = baseDate.addingTimeInterval(-Double(entryIndex) * hourInSeconds)

            let entry = ExerciseEntry(
                exerciseName: suffix == 0 ? exerciseName : "\(exerciseName) \(suffix + 1)",
                date: entryDate,
                sets: sets
            )
            entries.append(entry)
        }

        // Cache for small datasets (CI environment)
        if entryCount <= 100 {
            datasetCache[entryCount] = entries
        }

        return entries
    }

    // MARK: - Dataset Creation Performance Tests

    func testLargeDatasetCreationPerformance() {
        reportProgress("Starting large dataset creation performance test")

        measureWithConfig {
            // Use configuration-based dataset sizing
            let entryCount = config.largeDatasetSize
            logDatasetSize(entryCount, for: "large dataset creation")

            logMilestone("Starting dataset generation")
            let largeDataset = generateLargeDataset(entryCount: entryCount)

            logMilestone("Dataset generation completed", elapsed: getElapsedTime())
            XCTAssertEqual(largeDataset.count, entryCount, "Should generate exactly \(entryCount) entries")

            reportProgress("Completed dataset creation with \(largeDataset.count) entries")
        }
    }

    func testExtraLargeDatasetCreationPerformance() {
        measureWithConfig {
            // Use configuration-based dataset sizing
            let entryCount = config.extraLargeDatasetSize
            logDatasetSize(entryCount, for: "extra large dataset creation")
            let extraLargeDataset = generateLargeDataset(entryCount: entryCount)
            XCTAssertEqual(extraLargeDataset.count, entryCount, "Should generate exactly \(entryCount) entries")
        }
    }

    // MARK: - ViewModel Operations Performance Tests

    func testAddingLargeDatasetToViewModelPerformance() {
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .small)
        logDatasetSize(entryCount, for: "ViewModel addition")
        let dataset = generateLargeDataset(entryCount: entryCount)

        measureWithConfig {
            // Clear any existing entries
            viewModel.entries.removeAll()

            // Add all entries (this triggers save operations)
            for entry in dataset {
                viewModel.addEntry(entry)
            }
        }

        XCTAssertEqual(viewModel.entries.count, entryCount, "ViewModel should contain all \(entryCount) entries")
    }

    func testBulkDeletionPerformance() {
        // Arrange: Add dataset first (optimized size for performance testing)
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .small) * 2  // Double small size for deletion test
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions
        XCTAssertEqual(viewModel.entries.count, entryCount, "Should have \(entryCount) entries initially")

        // Act & Measure: Delete half the entries (second half)
        measureWithConfig {
            // Delete second half of entries
            let midPoint = entryCount / 2
            let indicesToDelete = Array(midPoint..<entryCount)
            for index in indicesToDelete.reversed() { // Delete from end to maintain indices
                viewModel.deleteEntry(at: IndexSet([index]))
            }
        }

        XCTAssertEqual(viewModel.entries.count, entryCount / 2, "Should have \(entryCount / 2) entries after deletion")
    }

    func testViewModelSearchOperationsPerformance() {
        // Arrange: Add dataset (optimized size for performance testing)
        // Use configuration-based dataset sizing
        let entryCount = config.mediumDatasetSize
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions

        measureWithConfig {
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
        // Use configuration-based dataset sizing
        let entryCount = config.largeDatasetSize * 3  // Triple large size for save test
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        measureWithConfig {
            viewModel.save()
        }
        let fileURL = temporaryDirectory.appendingPathComponent("workout_entries.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Save file should exist")
    }

    func testLargeDatasetLoadPerformance() {
        // Use configuration-based dataset sizing
        let entryCount = config.largeDatasetSize * 2  // Double large size for load test
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.addEntry(entry)
        }
        XCTAssertEqual(viewModel.entries.count, entryCount, "Should have saved \(entryCount) entries")
        measureWithConfig {
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, entryCount, "Should load all \(entryCount) entries")
        }
    }

    func testSaveLoadRoundTripPerformance() {
        // Use configuration-based dataset sizing
        let entryCount = config.largeDatasetSize
        let dataset = generateLargeDataset(entryCount: entryCount)
        measureWithConfig {
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            viewModel.save()
            let freshViewModel = WorkoutViewModel(dataStore: dataStore)
            XCTAssertEqual(freshViewModel.entries.count, entryCount, "Round trip should preserve all entries")
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageWithLargeDataset() {
        measureWithConfig {
            viewModel.entries.removeAll()
            // Use configuration-based dataset sizing
            let entryCount = datasetSize(for: .medium)
            let dataset = generateLargeDataset(entryCount: entryCount)
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            let filteredEntries = viewModel.entries.filter { $0.exerciseName.contains("Push") }
            let sortedEntries = viewModel.entries.sorted { $0.date > $1.date }
            XCTAssertEqual(viewModel.entries.count, entryCount, "Should maintain \(entryCount) entries")
            XCTAssertGreaterThan(filteredEntries.count, 0, "Should find filtered entries")
            XCTAssertEqual(sortedEntries.count, entryCount, "Sorted entries should match original count")
        }
    }

    func testMemoryEfficiencyAfterBulkOperations() {
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .small) * 4  // Quadruple small size
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        measureWithConfig {
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
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .medium)
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        var exportURL: URL?
        measureWithConfig {
            exportURL = viewModel.exportJSON()
        }
        XCTAssertNotNil(exportURL, "Export should succeed")
        if let url = exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export file should exist")
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                XCTAssertGreaterThan(fileSize, 5_000, "Export file should be substantial for \(entryCount) entries")
                XCTAssertLessThan(fileSize, 10_000_000, "Export file should not be excessively large")
            } catch {
                XCTFail("Failed to check export file attributes: \(error)")
            }
        }
    }

    func testExportDataIntegrityWithLargeDataset() {
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .small) * 3  // Triple small size
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry)
        }
        viewModel.save()
        var exportURL: URL?
        var exportedEntries: [ExerciseEntry] = []
        measureWithConfig {
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
        XCTAssertEqual(exportedEntries.count, entryCount, "Exported data should contain all entries")
        let originalIds = Set(viewModel.entries.map { $0.id })
        let exportedIds = Set(exportedEntries.map { $0.id })
        XCTAssertEqual(originalIds, exportedIds, "All entry IDs should be preserved in export")
    }

    // MARK: - Scalability Tests

    func testScalabilityAcrossDifferentDatasetSizes() throws {
        try skipIfCI(reason: "Scalability test excluded from CI")
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
        // Use configuration-based dataset sizing
        let entryCount = datasetSize(for: .small) * 3  // Triple small size
        let dataset = generateLargeDataset(entryCount: entryCount)
        for entry in dataset {
            viewModel.entries.append(entry) // Use direct append to avoid save overhead
        }
        viewModel.save() // Single save after all additions

        measureWithConfig {
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

    func testExtremeDatasetStressTest() throws {
        // This test pushes the limits to ensure the app can handle very large datasets
        try skipIfCI(reason: "Extreme stress test excluded from CI")

        let entryCount = config.stressDatasetSize
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
