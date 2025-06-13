import XCTest
import Foundation

/// Base test case class providing environment-aware configuration and utilities
open class ConfigurableTestCase: XCTestCase {

    /// Shared test configuration
    public let config = TestConfiguration.shared

    /// Test start time for execution monitoring
    private var testStartTime: Date?

    /// Category of the current test
    open var testCategory: TestCategory {
        .unit // Default, should be overridden by subclasses
    }

    // MARK: - Setup and Teardown

    override open func setUp() {
        super.setUp()
        testStartTime = Date()
    }

    override open func tearDown() {
        // Log test execution time if it exceeds warning threshold
        if let startTime = testStartTime {
            let executionTime = Date().timeIntervalSince(startTime)
            if executionTime > config.testWarningThreshold {
                let msg = "⚠️ Test '\(name)' took \(String(format: "%.2f", executionTime))s"
                NSLog("\(msg) (threshold: \(config.testWarningThreshold)s)")
            }
        }

        testStartTime = nil
        super.tearDown()
    }

    // MARK: - Test Utilities

    /// Skip test if running in CI environment
    public func skipIfCI(reason: String = "Skipped in CI environment") throws {
        if config.isCI {
            if #available(iOS 13.0, macOS 10.15, *) {
                throw XCTSkip(reason)
            } else {
                // Fallback for older versions
                continueAfterFailure = false
                NSLog("⏭️ Test skipped: \(reason)")
                return
            }
        }
    }

    /// Skip test if running in local environment
    public func skipIfLocal(reason: String = "Skipped in local environment") throws {
        if !config.isCI {
            if #available(iOS 13.0, macOS 10.15, *) {
                throw XCTSkip(reason)
            } else {
                // Fallback for older versions
                continueAfterFailure = false
                NSLog("⏭️ Test skipped: \(reason)")
                return
            }
        }
    }

    /// Skip test based on category
    public func skipIfCategory(_ category: TestCategory, reason: String? = nil) throws {
        if testCategory == category && !config.shouldRun(category) {
            let defaultReason = "\(category.description) tests skipped in \(config.environmentName) environment"
            if #available(iOS 13.0, macOS 10.15, *) {
                throw XCTSkip(reason ?? defaultReason)
            } else {
                // Fallback for older versions
                continueAfterFailure = false
                NSLog("⏭️ Test skipped: \(reason ?? defaultReason)")
                return
            }
        }
    }

    // MARK: - Performance Measurement

    /// Measure performance with environment-specific configuration
    public func measureWithConfig(
        metrics: [XCTMetric] = [XCTClockMetric()],
        options automaticOptions: XCTMeasureOptions = .default,
        block: () throws -> Void
    ) rethrows {
        var options = automaticOptions
        options.iterationCount = config.performanceMeasureIterations

        measure(metrics: metrics, options: options) {
            do {
                try block()
            } catch {
                XCTFail("Measurement block threw error: \(error)")
            }
        }
    }

    /// Measure with custom iteration count
    public func measureWithIterations(
        _ iterations: Int? = nil,
        block: () throws -> Void
    ) rethrows {
        var options = XCTMeasureOptions()
        options.iterationCount = iterations ?? config.performanceMeasureIterations

        measure(options: options) {
            do {
                try block()
            } catch {
                XCTFail("Measurement block threw error: \(error)")
            }
        }
    }

    // MARK: - Dataset Generation

    /// Get dataset size for category with optional override
    public func datasetSize(
        for category: DatasetCategory,
        override: Int? = nil
    ) -> Int {
        if let override = override {
            return override
        }
        return config.datasetSize(for: category)
    }

    /// Log dataset size being used
    public func logDatasetSize(_ size: Int, for operation: String) {
        NSLog("📊 Using dataset size \(size) for \(operation) in \(config.environmentName) environment")
    }

    // MARK: - Timeout Management

    /// Execute with timeout based on configuration
    public func executeWithTimeout(
        timeout: TimeInterval? = nil,
        work: @escaping () throws -> Void
    ) throws {
        let timeoutValue = timeout ?? config.defaultTimeout

        let expectation = XCTestExpectation(description: "Operation timeout")

        DispatchQueue.global().async {
            do {
                try work()
                expectation.fulfill()
            } catch {
                XCTFail("Operation failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeoutValue)
    }

    // MARK: - Memory Management

    /// Check memory usage and warn if threshold exceeded
    public func checkMemoryUsage(operation: String) {
        guard config.enableMemoryProfiling else { return }

        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory
        let memoryUsageMB = Int(physicalMemory / 1024 / 1024)

        if memoryUsageMB > config.memoryWarningThreshold {
            let msg = "⚠️ High memory usage detected for \(operation): \(memoryUsageMB)MB"
            NSLog("\(msg) (threshold: \(config.memoryWarningThreshold)MB)")
        }
    }
}

// MARK: - Test Category Extensions

/// Extension for unit tests
open class UnitTestCase: ConfigurableTestCase {
    override open var testCategory: TestCategory { .unit }
}

/// Extension for integration tests
open class IntegrationTestCase: ConfigurableTestCase {
    override open var testCategory: TestCategory { .integration }
}

/// Extension for performance tests
open class PerformanceTestCase: ConfigurableTestCase {
    override open var testCategory: TestCategory { .performance }
}

/// Extension for stress tests
open class StressTestCase: ConfigurableTestCase {
    override open var testCategory: TestCategory { .stress }
}
