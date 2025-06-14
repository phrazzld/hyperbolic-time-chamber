import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Example test demonstrating TestConfiguration usage
final class ConfigurationExampleTests: XCTestCase {

    let config = TestConfiguration.shared

    func testBasicConfiguration() {
        // Access configuration properties
        NSLog("Running in \(config.environmentName) environment")
        NSLog("Small dataset size: \(config.smallDatasetSize)")
        NSLog("Performance iterations: \(config.performanceMeasureIterations)")

        // Verify configuration is environment-aware
        if config.isCI {
            XCTAssertEqual(config.smallDatasetSize, 20)
            XCTAssertEqual(config.performanceMeasureIterations, 3)
        } else {
            XCTAssertEqual(config.smallDatasetSize, 100)
            XCTAssertEqual(config.performanceMeasureIterations, 10)
        }
    }

    func testDatasetSizing() {
        // Use dynamic dataset sizing with TestUtilities
        let smallData = generateTestData(count: TestUtilities.datasetSize(for: .small))
        let mediumData = generateTestData(count: TestUtilities.datasetSize(for: .medium))

        // Log for transparency
        TestUtilities.logDatasetSize(smallData.count, for: "unit test")

        // Verify data was generated
        XCTAssertEqual(smallData.count, config.smallDatasetSize)
        XCTAssertEqual(mediumData.count, config.mediumDatasetSize)
    }

    func testCIOnlyTest() throws {
        // This test only runs in CI
        try TestUtilities.skipIfLocal(in: self, reason: "This test validates CI-specific behavior")

        // CI-specific assertions
        XCTAssertTrue(config.isCI)
        XCTAssertTrue(config.useInMemoryStorage)
        XCTAssertEqual(config.maxParallelTests, 2)
    }

    func testLocalOnlyTest() throws {
        // This test only runs locally
        try TestUtilities.skipIfCI(in: self, reason: "This test requires local file system access")

        // Local-specific assertions
        XCTAssertFalse(config.isCI)
        XCTAssertFalse(config.useInMemoryStorage)
        XCTAssertTrue(config.enableMemoryProfiling)
    }

    func testExecutionMonitoring() {
        // Demonstrate execution monitoring capabilities
        TestUtilities.reportProgress("Starting execution monitoring demonstration")

        // Simulate some work with milestones
        Thread.sleep(forTimeInterval: 0.1)

        Thread.sleep(forTimeInterval: 0.2)

        // Test passes if no timeout occurs
        XCTAssertTrue(true)
    }

    // MARK: - Helper Methods

    private func generateTestData(count: Int) -> [ExerciseEntry] {
        WorkoutTestDataFactory.createOptimizedDataset(count: count)
    }
}
