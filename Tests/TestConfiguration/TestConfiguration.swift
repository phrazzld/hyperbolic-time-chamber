import Foundation
import os.log

/// Central configuration for test execution with environment-specific settings
public struct TestConfiguration {
    /// Shared instance for global access
    public static let shared = TestConfiguration()

    /// Whether tests are running in CI environment
    public let isCI: Bool

    /// Environment name for logging
    public var environmentName: String {
        isCI ? "CI" : "Local"
    }

    private init() {
        // Primary CI detection via GitHub Actions
        let environment = ProcessInfo.processInfo.environment
        self.isCI = environment["GITHUB_ACTIONS"] == "true" ||
                   environment["CI_BUILD"] == "true"

        // Log environment detection for debugging
        NSLog("🔧 TestConfiguration: Running in \(environmentName) environment")
    }

    // MARK: - Dataset Sizes

    /// Small dataset size (quick smoke tests)
    public var smallDatasetSize: Int {
        isCI ? 20 : 100
    }

    /// Medium dataset size (standard integration tests)
    public var mediumDatasetSize: Int {
        isCI ? 30 : 500
    }

    /// Large dataset size (performance tests)
    public var largeDatasetSize: Int {
        isCI ? 50 : 1000
    }

    /// Extra large dataset size (extended performance tests)
    public var extraLargeDatasetSize: Int {
        isCI ? 50 : 5000
    }

    /// Stress test dataset size (comprehensive stress tests)
    public var stressDatasetSize: Int {
        isCI ? 50 : 10000
    }

    // MARK: - Timeouts

    /// Default timeout for standard operations
    public var defaultTimeout: TimeInterval {
        isCI ? 5.0 : 10.0
    }

    /// Timeout for long-running operations
    public var longOperationTimeout: TimeInterval {
        isCI ? 30.0 : 60.0
    }

    /// Timeout for UI test interactions
    public var uiTestTimeout: TimeInterval {
        isCI ? 3.0 : 5.0
    }

    /// Timeout for performance tests
    public var performanceTestTimeout: TimeInterval {
        isCI ? 60.0 : 120.0
    }

    // MARK: - Performance Settings

    /// Number of iterations for performance measurements
    public var performanceMeasureIterations: Int {
        isCI ? 3 : 10
    }

    /// Whether to run stress tests
    public var shouldRunStressTests: Bool {
        !isCI
    }

    /// Whether to use in-memory storage for tests
    public var useInMemoryStorage: Bool {
        isCI
    }

    /// Maximum allowed test execution time before warning
    public var testWarningThreshold: TimeInterval {
        isCI ? 90.0 : 180.0
    }

    // MARK: - Parallelization

    /// Maximum parallel test execution workers
    public var maxParallelTests: Int {
        isCI ? 2 : ProcessInfo.processInfo.processorCount
    }

    /// Whether to run tests in parallel
    public var useParallelExecution: Bool {
        !isCI // Sequential in CI for more predictable performance
    }

    // MARK: - Memory Settings

    /// Maximum memory usage before warning (in MB)
    public var memoryWarningThreshold: Int {
        isCI ? 512 : 1024
    }

    /// Whether to enable memory profiling
    public var enableMemoryProfiling: Bool {
        !isCI // Disable in CI to reduce overhead
    }

    // MARK: - Test Execution Monitoring

    /// Whether to enable detailed test execution monitoring
    public var enableTestMonitoring: Bool {
        true // Always enabled for visibility
    }

    /// Whether to log progress during test execution
    public var enableProgressLogging: Bool {
        isCI // More verbose in CI to help debug timeouts
    }

    /// Threshold for marking tests as "slow" (in seconds)
    public var slowTestThreshold: TimeInterval {
        isCI ? 2.0 : 5.0
    }

    /// Threshold for marking tests as "very slow" (in seconds)
    public var verySlowTestThreshold: TimeInterval {
        isCI ? 5.0 : 10.0
    }

    /// Interval for progress reporting during long test suites (in seconds)
    public var progressReportingInterval: TimeInterval {
        isCI ? 30.0 : 60.0
    }

    /// Whether to generate structured JSON output for CI parsing
    public var enableStructuredOutput: Bool {
        isCI
    }

    /// Maximum number of slowest tests to report in summary
    public var maxSlowTestsToReport: Int {
        isCI ? 10 : 20
    }
}

// MARK: - Convenience Methods

public extension TestConfiguration {
    /// Get dataset size for a given category
    func datasetSize(for category: DatasetCategory) -> Int {
        switch category {
        case .small: return smallDatasetSize
        case .medium: return mediumDatasetSize
        case .large: return largeDatasetSize
        case .extraLarge: return extraLargeDatasetSize
        case .stress: return stressDatasetSize
        }
    }

    /// Check if a test category should run in current environment
    func shouldRun(_ category: TestCategory) -> Bool {
        switch category {
        case .unit, .integration:
            return true
        case .performance:
            return true // Always run, but with adjusted dataset sizes
        case .stress:
            return shouldRunStressTests
        }
    }
}

/// Dataset size categories
public enum DatasetCategory {
    case small
    case medium
    case large
    case extraLarge
    case stress
}

/// Test execution categories
public enum TestCategory {
    case unit           // < 0.1s - Basic unit tests
    case integration    // 0.1s - 1s - Integration tests
    case performance    // 1s - 10s - Performance tests
    case stress        // > 10s - Stress tests

    /// Human-readable description
    public var description: String {
        switch self {
        case .unit: return "Unit"
        case .integration: return "Integration"
        case .performance: return "Performance"
        case .stress: return "Stress"
        }
    }
}
