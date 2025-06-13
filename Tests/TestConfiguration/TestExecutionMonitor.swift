// swiftlint:disable file_length type_body_length
import Foundation
import XCTest
import os.log

/// Centralized monitoring for test execution performance and progress
public class TestExecutionMonitor {
    /// Shared instance for global test monitoring
    public static let shared = TestExecutionMonitor()

    /// Configuration for monitoring behavior
    private let config = TestConfiguration.shared

    /// Individual test execution record
    public struct TestExecution {
        public let testName: String
        public let testClass: String
        public let category: TestCategory
        public let startTime: Date
        public let endTime: Date
        public let duration: TimeInterval
        public let passed: Bool
        public let skipped: Bool

        public var isSlowTest: Bool {
            duration >= TestConfiguration.shared.slowTestThreshold
        }

        public var isVerySlowTest: Bool {
            duration >= TestConfiguration.shared.verySlowTestThreshold
        }
    }

    /// Test suite execution record
    public struct TestSuiteExecution {
        public let suiteName: String
        public let startTime: Date
        public var endTime: Date?
        public var tests: [TestExecution] = []

        public var duration: TimeInterval {
            guard let endTime = endTime else { return Date().timeIntervalSince(startTime) }
            return endTime.timeIntervalSince(startTime)
        }

        public var testCount: Int { tests.count }
        public var passedCount: Int { tests.filter { $0.passed && !$0.skipped }.count }
        public var failedCount: Int { tests.filter { !$0.passed && !$0.skipped }.count }
        public var skippedCount: Int { tests.filter { $0.skipped }.count }
    }

    // MARK: - State Management

    private var currentTestSuites: [String: TestSuiteExecution] = [:]
    private var completedTestSuites: [TestSuiteExecution] = []
    private struct CurrentTestInfo {
        let suite: String
        let test: String
        let startTime: Date
        var hasReceivedEarlyWarning: Bool = false
        var hasReceivedFinalWarning: Bool = false
    }

    private var currentTest: CurrentTestInfo?
    private var lastProgressReport = Date()
    private var timeoutCheckTimer: Timer?

    private let queue = DispatchQueue(label: "TestExecutionMonitor", qos: .utility)

    private init() {
        setupExitHandler()
    }

    // MARK: - Timeout Monitoring

    /// Start timeout monitoring timer
    private func startTimeoutMonitoring() {
        stopTimeoutMonitoring() // Stop any existing timer

        timeoutCheckTimer = Timer.scheduledTimer(
            withTimeInterval: config.timeoutCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkTimeoutWarnings()
        }
    }

    /// Stop timeout monitoring timer
    private func stopTimeoutMonitoring() {
        timeoutCheckTimer?.invalidate()
        timeoutCheckTimer = nil
    }

    /// Check if current test is approaching timeout thresholds
    private func checkTimeoutWarnings() {
        queue.async {
            guard var current = self.currentTest else { return }

            let elapsed = Date().timeIntervalSince(current.startTime)
            let earlyThreshold = self.config.earlyWarningThreshold
            let finalThreshold = self.config.testWarningThreshold

            // Early warning (75% of threshold)
            if elapsed >= earlyThreshold && !current.hasReceivedEarlyWarning {
                self.logEarlyTimeoutWarning(testName: current.test, elapsed: elapsed, threshold: finalThreshold)
                current.hasReceivedEarlyWarning = true
                self.currentTest = current
            }

            // Final warning (90s threshold)
            if elapsed >= finalThreshold && !current.hasReceivedFinalWarning {
                self.logFinalTimeoutWarning(testName: current.test, elapsed: elapsed, threshold: finalThreshold)
                current.hasReceivedFinalWarning = true
                self.currentTest = current
            }

            // Critical warning (exceeded threshold by 10s)
            if elapsed >= finalThreshold + 10.0 {
                self.logCriticalTimeoutWarning(testName: current.test, elapsed: elapsed)
            }
        }
    }

    /// Log early timeout warning (75% of threshold)
    private func logEarlyTimeoutWarning(testName: String, elapsed: TimeInterval, threshold: TimeInterval) {
        let remaining = threshold - elapsed
        let percent = Int((elapsed / threshold) * 100)

        let message = """
        ⚠️ EARLY TIMEOUT WARNING
        Test: \(testName)
        Elapsed: \(String(format: "%.1f", elapsed))s (\(percent)% of threshold)
        Remaining: \(String(format: "%.1f", remaining))s until \(String(format: "%.0f", threshold))s threshold
        Environment: \(config.environmentName)

        💡 Consider:
        - Reducing dataset size for this test in CI
        - Optimizing test algorithms for better performance
        - Breaking down complex test into smaller units
        """

        NSLog("%@", message)
    }

    /// Log final timeout warning (reached threshold)
    private func logFinalTimeoutWarning(testName: String, elapsed: TimeInterval, threshold: TimeInterval) {
        let message = """
        🚨 FINAL TIMEOUT WARNING
        Test: \(testName)
        Status: EXCEEDED \(String(format: "%.0f", threshold))s threshold
        Elapsed: \(String(format: "%.1f", elapsed))s
        Environment: \(config.environmentName)

        ⚠️ Test execution may be terminated soon!
        Check for infinite loops, hanging I/O, or excessive computation.
        """

        NSLog("%@", message)
    }

    /// Log critical timeout warning (well beyond threshold)
    private func logCriticalTimeoutWarning(testName: String, elapsed: TimeInterval) {
        let message = """
        🔥 CRITICAL: Test \(testName) has been running for \(String(format: "%.1f", elapsed))s
        This test should be terminated to prevent CI timeout.
        """

        NSLog("%@", message)
    }

    // MARK: - Public Interface

    /// Start monitoring a test suite
    public func startTestSuite(_ suiteName: String) {
        queue.async {
            let suite = TestSuiteExecution(suiteName: suiteName, startTime: Date())
            self.currentTestSuites[suiteName] = suite

            if self.config.enableProgressLogging {
                NSLog("📊 Starting test suite: \(suiteName)")
            }
        }
    }

    /// End monitoring a test suite
    public func endTestSuite(_ suiteName: String) {
        queue.async {
            guard var suite = self.currentTestSuites[suiteName] else { return }

            suite.endTime = Date()
            self.completedTestSuites.append(suite)
            self.currentTestSuites.removeValue(forKey: suiteName)

            if self.config.enableProgressLogging {
                let summary = self.generateSuiteSummary(suite)
                NSLog("✅ Completed test suite: \(suiteName) - \(summary)")
            }
        }
    }

    /// Start monitoring an individual test
    public func startTest(
        _ testName: String,
        in suiteName: String,
        category: TestCategory = .unit
    ) {
        queue.async {
            self.currentTest = CurrentTestInfo(suite: suiteName, test: testName, startTime: Date())

            // Start timeout monitoring for this test
            DispatchQueue.main.async {
                self.startTimeoutMonitoring()
            }

            if self.config.enableProgressLogging {
                self.reportProgressIfNeeded()
            }
        }
    }

    /// End monitoring an individual test
    public func endTest(
        _ testName: String,
        in suiteName: String,
        passed: Bool,
        skipped: Bool = false,
        category: TestCategory = .unit
    ) {
        queue.async {
            guard let current = self.currentTest,
                  current.suite == suiteName,
                  current.test == testName else { return }

            // Stop timeout monitoring for this test
            DispatchQueue.main.async {
                self.stopTimeoutMonitoring()
            }

            let endTime = Date()
            let duration = endTime.timeIntervalSince(current.startTime)

            let execution = TestExecution(
                testName: testName,
                testClass: suiteName,
                category: category,
                startTime: current.startTime,
                endTime: endTime,
                duration: duration,
                passed: passed,
                skipped: skipped
            )

            // Add to current suite
            if var suite = self.currentTestSuites[suiteName] {
                suite.tests.append(execution)
                self.currentTestSuites[suiteName] = suite
            }

            // Log slow tests immediately
            self.logSlowTestIfNeeded(execution)

            self.currentTest = nil
        }
    }

    /// Generate comprehensive monitoring report
    public func generateReport() -> String {
        var report = "\n" + String(repeating: "=", count: 80) + "\n"
        report += "📊 TEST EXECUTION MONITORING REPORT\n"
        report += String(repeating: "=", count: 80) + "\n"

        let allSuites = completedTestSuites + currentTestSuites.values
        let allTests = allSuites.flatMap { $0.tests }

        // Overall statistics
        report += generateOverallStatistics(suites: allSuites, tests: allTests)

        // Slowest tests
        report += generateSlowestTestsReport(tests: allTests)

        // Suite breakdown
        report += generateSuiteBreakdown(suites: allSuites)

        // CI-specific structured output
        if config.enableStructuredOutput {
            report += generateStructuredOutput(suites: allSuites, tests: allTests)
        }

        report += String(repeating: "=", count: 80) + "\n"
        return report
    }

    // MARK: - Private Implementation

    private func setupExitHandler() {
        // Generate final report on test completion
        atexit {
            // Ensure timeout monitoring is stopped
            TestExecutionMonitor.shared.stopTimeoutMonitoring()

            let report = TestExecutionMonitor.shared.generateReport()
            NSLog("%@", report)
        }
    }

    private func reportProgressIfNeeded() {
        let now = Date()
        let timeSinceLastReport = now.timeIntervalSince(lastProgressReport)

        if timeSinceLastReport >= config.progressReportingInterval {
            let activeSuites = currentTestSuites.count
            let completedSuites = completedTestSuites.count
            let allSuites = completedTestSuites + currentTestSuites.values
            let totalTests = allSuites.flatMap { $0.tests }.count

            var message = "⏱️ Progress: \(completedSuites) suites completed, \(activeSuites) active, " +
                         "\(totalTests) tests executed"

            // Add current test information if available
            if let current = currentTest {
                let elapsed = now.timeIntervalSince(current.startTime)
                let threshold = config.testWarningThreshold
                let percent = min(100, Int((elapsed / threshold) * 100))
                message += " | Current: \(current.test) (\(String(format: "%.1f", elapsed))s, \(percent)%)"
            }

            NSLog(message)
            lastProgressReport = now
        }
    }

    private func logSlowTestIfNeeded(_ execution: TestExecution) {
        if execution.isVerySlowTest {
            let msg = "🐌 Very slow test: \(execution.testName)"
            NSLog("\(msg) (\(String(format: "%.2f", execution.duration))s)")
        } else if execution.isSlowTest && config.enableProgressLogging {
            let msg = "⚠️ Slow test: \(execution.testName)"
            NSLog("\(msg) (\(String(format: "%.2f", execution.duration))s)")
        }
    }

    private func generateSuiteSummary(_ suite: TestSuiteExecution) -> String {
        let duration = String(format: "%.2f", suite.duration)
        return "\(suite.testCount) tests in \(duration)s (\(suite.passedCount) passed, " +
               "\(suite.failedCount) failed, \(suite.skippedCount) skipped)"
    }

    private func generateOverallStatistics(suites: [TestSuiteExecution], tests: [TestExecution]) -> String {
        let totalDuration = suites.reduce(0) { $0 + $1.duration }
        let totalTests = tests.count
        let passedTests = tests.filter { $0.passed && !$0.skipped }.count
        let failedTests = tests.filter { !$0.passed && !$0.skipped }.count
        let skippedTests = tests.filter { $0.skipped }.count

        let slowTests = tests.filter { $0.isSlowTest }.count
        let verySlowTests = tests.filter { $0.isVerySlowTest }.count
        let timeoutThresholdTests = tests.filter { $0.duration >= config.testWarningThreshold }.count

        var stats = "\n📈 OVERALL STATISTICS\n"
        stats += "• Total Execution Time: \(String(format: "%.2f", totalDuration))s\n"
        stats += "• Total Test Suites: \(suites.count)\n"
        stats += "• Total Tests: \(totalTests)\n"
        stats += "• Passed: \(passedTests) | Failed: \(failedTests) | Skipped: \(skippedTests)\n"
        stats += "• Slow Tests (≥\(config.slowTestThreshold)s): \(slowTests)\n"
        stats += "• Very Slow Tests (≥\(config.verySlowTestThreshold)s): \(verySlowTests)\n"
        let timeoutThreshold = String(format: "%.0f", config.testWarningThreshold)
        stats += "• Tests Exceeding Timeout Threshold (≥\(timeoutThreshold)s): \(timeoutThresholdTests)\n"

        if totalTests > 0 {
            let avgDuration = tests.reduce(0) { $0 + $1.duration } / Double(totalTests)
            stats += "• Average Test Duration: \(String(format: "%.3f", avgDuration))s\n"
        }

        // Add timeout monitoring configuration info
        stats += "\n⚙️ TIMEOUT MONITORING CONFIGURATION\n"
        stats += "• Environment: \(config.environmentName)\n"
        stats += "• Warning Threshold: \(String(format: "%.0f", config.testWarningThreshold))s\n"
        let earlyWarningThreshold = String(format: "%.0f", config.earlyWarningThreshold)
        let earlyWarningPercent = Int(config.earlyWarningPercent * 100)
        stats += "• Early Warning: \(earlyWarningThreshold)s (\(earlyWarningPercent)% of threshold)\n"
        stats += "• Check Interval: \(String(format: "%.0f", config.timeoutCheckInterval))s\n"

        return stats + "\n"
    }

    private func generateSlowestTestsReport(tests: [TestExecution]) -> String {
        let slowestTests = tests
            .filter { $0.duration > 0.001 } // Filter out very fast tests
            .sorted { $0.duration > $1.duration }
            .prefix(config.maxSlowTestsToReport)

        guard !slowestTests.isEmpty else { return "" }

        var report = "🐌 SLOWEST TESTS\n"
        for (index, test) in slowestTests.enumerated() {
            let duration = String(format: "%.3f", test.duration)
            let status = test.passed ? "✅" : "❌"
            let category = test.category.description
            report += "\(index + 1). \(status) \(test.testName) (\(category)) - \(duration)s\n"
        }

        return report + "\n"
    }

    private func generateSuiteBreakdown(suites: [TestSuiteExecution]) -> String {
        guard !suites.isEmpty else { return "" }

        var breakdown = "📋 TEST SUITE BREAKDOWN\n"
        for suite in suites.sorted(by: { $0.duration > $1.duration }) {
            let duration = String(format: "%.2f", suite.duration)
            let summary = generateSuiteSummary(suite)
            breakdown += "• \(suite.suiteName): \(duration)s - \(summary)\n"
        }

        return breakdown + "\n"
    }

    private func generateStructuredOutput(suites: [TestSuiteExecution], tests: [TestExecution]) -> String {
        let totalDuration = suites.reduce(0) { $0 + $1.duration }
        let slowTests = tests.filter { $0.isSlowTest }

        let output: [String: Any] = [
            "test_execution_summary": [
                "total_duration_seconds": totalDuration,
                "total_suites": suites.count,
                "total_tests": tests.count,
                "slow_tests_count": slowTests.count,
                "slowest_tests": slowTests.prefix(5).map { test in
                    [
                        "name": test.testName,
                        "duration_seconds": test.duration,
                        "category": test.category.description
                    ]
                }
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return "📄 STRUCTURED OUTPUT (JSON)\n\(jsonString)\n\n"
        }

        return ""
    }
}

// MARK: - XCTestObservation Integration

/// Test observation to automatically integrate with XCTest execution
public class TestExecutionObserver: NSObject, XCTestObservation {
    private let monitor = TestExecutionMonitor.shared

    public func testSuiteWillStart(_ testSuite: XCTestSuite) {
        monitor.startTestSuite(testSuite.name)
    }

    public func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        monitor.endTestSuite(testSuite.name)
    }

    public func testCaseWillStart(_ testCase: XCTestCase) {
        let category: TestCategory
        switch testCase {
        case is PerformanceTestCase: category = .performance
        case is IntegrationTestCase: category = .integration
        case is StressTestCase: category = .stress
        default: category = .unit
        }

        monitor.startTest(
            testCase.name,
            in: type(of: testCase).description(),
            category: category
        )
    }

    public func testCaseDidFinish(_ testCase: XCTestCase) {
        let suiteName = type(of: testCase).description()
        let passed = testCase.testRun?.hasSucceeded ?? false
        let skipped = testCase.testRun?.hasBeenSkipped ?? false

        let category: TestCategory
        switch testCase {
        case is PerformanceTestCase: category = .performance
        case is IntegrationTestCase: category = .integration
        case is StressTestCase: category = .stress
        default: category = .unit
        }

        monitor.endTest(
            testCase.name,
            in: suiteName,
            passed: passed,
            skipped: skipped,
            category: category
        )
    }
}
// swiftlint:enable file_length type_body_length
