import XCTest
import Foundation
import TestConfiguration
@testable import WorkoutTracker

/// Example test demonstrating TestConfiguration usage
final class ConfigurationExampleTests: UnitTestCase {

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
        // Use dynamic dataset sizing
        let smallData = generateTestData(count: datasetSize(for: .small))
        let mediumData = generateTestData(count: datasetSize(for: .medium))

        // Log for transparency
        logDatasetSize(smallData.count, for: "unit test")

        // Verify data was generated
        XCTAssertEqual(smallData.count, config.smallDatasetSize)
        XCTAssertEqual(mediumData.count, config.mediumDatasetSize)
    }

    func testCIOnlyTest() throws {
        // This test only runs in CI
        try skipIfLocal(reason: "This test validates CI-specific behavior")

        // CI-specific assertions
        XCTAssertTrue(config.isCI)
        XCTAssertTrue(config.useInMemoryStorage)
        XCTAssertEqual(config.maxParallelTests, 2)
    }

    func testLocalOnlyTest() throws {
        // This test only runs locally
        try skipIfCI(reason: "This test requires local file system access")

        // Local-specific assertions
        XCTAssertFalse(config.isCI)
        XCTAssertFalse(config.useInMemoryStorage)
        XCTAssertTrue(config.enableMemoryProfiling)
    }

    // Helper to generate test data
    private func generateTestData(count: Int) -> [String] {
        (0..<count).map { "Item \($0)" }
    }
}
