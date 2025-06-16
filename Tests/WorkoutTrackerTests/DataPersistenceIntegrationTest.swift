import XCTest
@testable import WorkoutTracker

final class DataPersistenceIntegrationTest: XCTestCase {

    func testDataPersistenceWorkflowWithDependencyInjection() throws {
        let setup = try setupInitialTest()
        let (restartedViewModel, actualFileURL) = try testAddEntriesAndPersistence(
            viewModel: setup.viewModel,
            configuration: setup.configuration,
            tempDir: setup.tempDir
        )
        let exportURL = try testExportFunctionality(viewModel: restartedViewModel)
        try testDeleteFunctionality(viewModel: restartedViewModel, configuration: setup.configuration)
        cleanupTestFiles(actualFileURL: actualFileURL, exportURL: exportURL)
    }

    private struct TestSetup {
        let viewModel: WorkoutViewModel
        let configuration: DependencyFactory.Configuration
        let tempDir: URL
    }

    private func setupInitialTest() throws -> TestSetup {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileName = "integration_test_entries.json"

        // Clean up any previous test files
        let testFileURL = tempDir.appendingPathComponent(testFileName)
        try? FileManager.default.removeItem(at: testFileURL)

        let configuration = DependencyFactory.Configuration(
            isDemo: false,
            isScreenshotMode: false,
            isUITesting: false,
            fileManager: .default,
            baseDirectory: tempDir
        )
        let viewModel = try DependencyFactory.createViewModel(configuration: configuration)

        XCTAssertEqual(viewModel.entries.count, 0, "New ViewModel should start with no entries")
        return TestSetup(viewModel: viewModel, configuration: configuration, tempDir: tempDir)
    }

    private func testAddEntriesAndPersistence(
        viewModel: WorkoutViewModel,
        configuration: DependencyFactory.Configuration,
        tempDir: URL
    ) throws -> (WorkoutViewModel, URL) {
        let benchPress = ExerciseEntry(
            exerciseName: "Bench Press",
            date: Date(),
            sets: [
                ExerciseSet(reps: 10, weight: 135.0, notes: "Warm up"),
                ExerciseSet(reps: 8, weight: 155.0, notes: "Working set"),
                ExerciseSet(reps: 6, weight: 175.0, notes: "PR attempt")
            ]
        )

        let squats = ExerciseEntry(
            exerciseName: "Squats",
            date: Date(),
            sets: [
                ExerciseSet(reps: 12, weight: 225.0),
                ExerciseSet(reps: 10, weight: 245.0),
                ExerciseSet(reps: 8, weight: 265.0)
            ]
        )

        viewModel.addEntry(benchPress)
        viewModel.addEntry(squats)

        XCTAssertEqual(viewModel.entries.count, 2, "Should have 2 entries after adding")
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Bench Press")
        XCTAssertEqual(viewModel.entries[1].exerciseName, "Squats")

        let actualFileURL = tempDir.appendingPathComponent("workout_entries.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: actualFileURL.path),
            "Data file should exist after adding entries"
        )

        let restartedViewModel = try DependencyFactory.createViewModel(configuration: configuration)
        XCTAssertEqual(restartedViewModel.entries.count, 2, "Restarted app should load 2 entries from disk")
        XCTAssertEqual(restartedViewModel.entries[0].exerciseName, "Bench Press")
        XCTAssertEqual(restartedViewModel.entries[1].exerciseName, "Squats")

        return (restartedViewModel, actualFileURL)
    }

    private func testExportFunctionality(viewModel: WorkoutViewModel) throws -> URL? {
        let exportURL = viewModel.exportJSON()
        XCTAssertNotNil(exportURL, "Export should succeed and return URL")

        if let exportURL = exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")

            let exportedData = try Data(contentsOf: exportURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exportedEntries = try decoder.decode([ExerciseEntry].self, from: exportedData)

            XCTAssertEqual(exportedEntries.count, 2, "Exported data should contain 2 entries")
            XCTAssertEqual(exportedEntries[0].exerciseName, "Bench Press")
        }

        return exportURL
    }

    private func testDeleteFunctionality(
        viewModel: WorkoutViewModel,
        configuration: DependencyFactory.Configuration
    ) throws {
        viewModel.deleteEntry(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.entries.count, 1, "Should have 1 entry after deletion")
        XCTAssertEqual(viewModel.entries[0].exerciseName, "Squats", "Remaining entry should be Squats")

        let finalViewModel = try DependencyFactory.createViewModel(configuration: configuration)
        XCTAssertEqual(finalViewModel.entries.count, 1, "Deletion should be persisted")
        XCTAssertEqual(finalViewModel.entries[0].exerciseName, "Squats")
    }

    private func cleanupTestFiles(actualFileURL: URL, exportURL: URL?) {
        try? FileManager.default.removeItem(at: actualFileURL)
        if let exportURL = exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
    }

    func testEnvironmentSpecificBehavior() throws {
        // Test that different environments create appropriate DataStore implementations

        // Test production environment
        let prodConfig = DependencyFactory.Configuration(
            isDemo: false,
            isScreenshotMode: false,
            isUITesting: false
        )
        let prodViewModel = try DependencyFactory.createViewModel(configuration: prodConfig)
        // This should use FileDataStore internally

        // Test demo environment  
        let demoConfig = DependencyFactory.Configuration(
            isDemo: true,
            isScreenshotMode: false,
            isUITesting: false
        )
        let demoViewModel = try DependencyFactory.createViewModel(configuration: demoConfig)
        // This should use InMemoryDataStore with demo data

        // Test UI testing environment
        let testConfig = DependencyFactory.Configuration(
            isDemo: false,
            isScreenshotMode: false,
            isUITesting: true
        )
        let testViewModel = try DependencyFactory.createViewModel(configuration: testConfig)
        // This should use InMemoryDataStore for isolated testing

        // All ViewModels should be functional
        XCTAssertNotNil(prodViewModel)
        XCTAssertNotNil(demoViewModel)
        XCTAssertNotNil(testViewModel)

        // Demo and test environments should start with clean state by default
        // (unless preloaded with demo data, which depends on DemoDataService implementation)

        // All should support adding entries regardless of environment
        let testEntry = ExerciseEntry(exerciseName: "Environment Test", date: Date(), sets: [])

        prodViewModel.addEntry(testEntry)
        demoViewModel.addEntry(testEntry)
        testViewModel.addEntry(testEntry)

        XCTAssertTrue(prodViewModel.entries.contains { $0.exerciseName == "Environment Test" })
        XCTAssertTrue(demoViewModel.entries.contains { $0.exerciseName == "Environment Test" })
        XCTAssertTrue(testViewModel.entries.contains { $0.exerciseName == "Environment Test" })
    }
}
