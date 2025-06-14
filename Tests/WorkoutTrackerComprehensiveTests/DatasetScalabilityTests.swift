import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Comprehensive dataset scalability tests for local development environments
/// Tests performance across different dataset sizes to verify scalability characteristics
final class DatasetScalabilityTests: PerformanceTestCase {

    private var temporaryDirectory: URL!
    private var dataStore: DataStore!
    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()

        // Always use real file system for comprehensive tests
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

    // MARK: - Scalability Tests

    func testScalabilityAcrossDifferentDatasetSizes() throws {
        try skipIfCI(reason: "Scalability test requires larger datasets - local development only")

        let sizes = [100, 500, 1000, 2500]
        var addTimes: [Double] = []
        var saveTimes: [Double] = []
        var loadTimes: [Double] = []

        reportProgress("Testing scalability across dataset sizes: \(sizes)")

        for size in sizes {
            let dataset = generateRealisticDataset(count: size)
            reportProgress("Testing with dataset size: \(size)")

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

            // Measure load time
            let loadStartTime = Date()
            let loadViewModel = WorkoutViewModel(dataStore: dataStore)
            let loadTime = Date().timeIntervalSince(loadStartTime)
            loadTimes.append(loadTime)

            XCTAssertEqual(loadViewModel.entries.count, size, "Should load all \(size) entries")
        }

        // Verify scalability - performance should scale reasonably
        reportProgress("Add times: \(addTimes.map { String(format: "%.3f", $0) })")
        reportProgress("Save times: \(saveTimes.map { String(format: "%.3f", $0) })")
        reportProgress("Load times: \(loadTimes.map { String(format: "%.3f", $0) })")

        // Performance should not degrade exponentially
        XCTAssertLessThan(addTimes[1] / addTimes[0], 10.0, "5x data should not take >10x time to add")
        XCTAssertLessThan(addTimes[2] / addTimes[0], 20.0, "10x data should not take >20x time to add")

        XCTAssertLessThan(saveTimes[1] / saveTimes[0], 8.0, "5x data should not take >8x time to save")
        XCTAssertLessThan(saveTimes[2] / saveTimes[0], 15.0, "10x data should not take >15x time to save")
    }

    func testMemoryScalabilityWithLargeDatasets() throws {
        try skipIfCI(reason: "Memory scalability test requires large datasets")

        let sizes = [500, 1500, 3000]

        for size in sizes {
            autoreleasepool {
                let dataset = generateRealisticDataset(count: size)
                reportProgress("Testing memory usage with \(size) entries")

                measureWithConfig {
                    viewModel.entries.removeAll()

                    for entry in dataset {
                        viewModel.entries.append(entry)
                    }

                    // Perform memory-intensive operations
                    let filteredEntries = viewModel.entries.filter { $0.exerciseName.contains("Push") }
                    let sortedEntries = viewModel.entries.sorted { $0.date > $1.date }
                    let groupedByExercise = Dictionary(grouping: viewModel.entries) { $0.exerciseName }

                    XCTAssertGreaterThan(filteredEntries.count, 0, "Should find filtered entries")
                    XCTAssertEqual(sortedEntries.count, size, "Sort should preserve count")
                    XCTAssertGreaterThan(groupedByExercise.count, 0, "Should group entries")
                }

                checkMemoryUsage(operation: "dataset size \(size)")
            }
        }
    }

    func testSearchPerformanceScalability() throws {
        try skipIfCI(reason: "Search scalability test requires large datasets")

        let sizes = [1000, 2500, 5000]

        for size in sizes {
            let dataset = generateRealisticDataset(count: size)

            // Setup dataset
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }

            reportProgress("Testing search performance with \(size) entries")

            measureWithConfig {
                // Test various search patterns
                let nameSearch = viewModel.entries.filter { $0.exerciseName.contains("Push-ups") }
                let dateSearch = viewModel.entries.filter { $0.date.timeIntervalSinceNow > -86400 * 30 }
                let weightSearch = viewModel.entries.filter { entry in
                    entry.sets.contains { $0.weight != nil && ($0.weight ?? 0) > 100 }
                }
                let complexSearch = viewModel.entries.filter { entry in
                    entry.exerciseName.contains("Bench") &&
                    entry.sets.count >= 3 &&
                    entry.date.timeIntervalSinceNow > -86400 * 7
                }

                XCTAssertGreaterThanOrEqual(nameSearch.count, 0, "Name search should complete")
                XCTAssertGreaterThanOrEqual(dateSearch.count, 0, "Date search should complete")
                XCTAssertGreaterThanOrEqual(weightSearch.count, 0, "Weight search should complete")
                XCTAssertGreaterThanOrEqual(complexSearch.count, 0, "Complex search should complete")
            }
        }
    }

    func testExportScalability() throws {
        try skipIfCI(reason: "Export scalability test requires large datasets")

        let sizes = [500, 1500, 3000]

        for size in sizes {
            let dataset = generateRealisticDataset(count: size)

            // Setup dataset
            viewModel.entries.removeAll()
            for entry in dataset {
                viewModel.entries.append(entry)
            }
            viewModel.save()

            reportProgress("Testing export performance with \(size) entries")

            var exportURL: URL?
            measureWithConfig {
                exportURL = viewModel.exportJSON()
            }

            XCTAssertNotNil(exportURL, "Export should succeed for \(size) entries")

            if let url = exportURL {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export file should exist")

                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    XCTAssertGreaterThan(fileSize, Int64(size * 100), "Export file should be reasonable size")
                    reportProgress("Export file size for \(size) entries: \(fileSize) bytes")
                } catch {
                    XCTFail("Failed to check export file attributes: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func generateRealisticDataset(count: Int) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Rows", "Dips", "Lunges", "Planks",
            "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
            "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
            "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls"
        ]

        let baseDate = Date()

        return (0..<count).map { index in
            let exerciseIndex = index % exerciseNames.count
            let exerciseName = exerciseNames[exerciseIndex]

            // Generate realistic sets
            let setCount = Int.random(in: 1...5)
            let sets = (0..<setCount).map { setIndex in
                let reps = Int.random(in: 5...20)
                let weight = setIndex == 0 ? nil : Double.random(in: 20...200)
                return ExerciseSet(reps: reps, weight: weight)
            }

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: baseDate.addingTimeInterval(-Double(index) * 3600),
                sets: sets
            )
        }
    }
}
