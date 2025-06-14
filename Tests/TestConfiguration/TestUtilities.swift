import Foundation
import XCTest

/// Lightweight test utilities for environment-aware testing without inheritance overhead
public struct TestUtilities {

    /// Shared configuration access
    public static let config = TestConfiguration.shared

    // MARK: - Environment Utilities

    /// Skip test if running in CI environment
    public static func skipIfCI(
        in testCase: XCTestCase,
        reason: String = "Skipped in CI environment"
    ) throws {
        if config.isCI {
            if #available(iOS 13.0, macOS 10.15, *) {
                throw XCTSkip(reason)
            } else {
                testCase.continueAfterFailure = false
                NSLog("⏭️ Test skipped: \(reason)")
                return
            }
        }
    }

    /// Skip test if running in local environment
    public static func skipIfLocal(
        in testCase: XCTestCase,
        reason: String = "Skipped in local environment"
    ) throws {
        if !config.isCI {
            if #available(iOS 13.0, macOS 10.15, *) {
                throw XCTSkip(reason)
            } else {
                testCase.continueAfterFailure = false
                NSLog("⏭️ Test skipped: \(reason)")
                return
            }
        }
    }

    // MARK: - Performance Utilities

    /// Get appropriate dataset size for environment
    public static func datasetSize(for category: DatasetCategory) -> Int {
        config.datasetSize(for: category)
    }

    /// Log dataset size being used
    public static func logDatasetSize(_ size: Int, for operation: String) {
        NSLog("📊 Using dataset size \(size) for \(operation) in \(config.environmentName) environment")
    }

    /// Report progress for long-running operations
    public static func reportProgress(
        _ message: String,
        testName: String = "",
        className: String = ""
    ) {
        if config.enableProgressLogging {
            let prefix = !className.isEmpty ? "\(className).\(testName)" : testName
            NSLog("📊 \(prefix): \(message)")
        }
    }

    // MARK: - Timeout Management

    /// Get appropriate timeout for environment
    public static func timeout() -> TimeInterval {
        config.defaultTimeout
    }

    /// Execute with environment-appropriate timeout
    public static func executeWithTimeout<T>(
        timeout: TimeInterval? = nil,
        work: @escaping () throws -> T
    ) throws -> T {
        let timeoutValue = timeout ?? config.defaultTimeout
        let expectation = XCTestExpectation(description: "Operation timeout")
        var result: Result<T, Error>?

        DispatchQueue.global().async {
            do {
                let value = try work()
                result = .success(value)
                expectation.fulfill()
            } catch {
                result = .failure(error)
                expectation.fulfill()
            }
        }

        let waiter = XCTWaiter()
        let waitResult = waiter.wait(for: [expectation], timeout: timeoutValue)

        guard waitResult == .completed else {
            throw TestUtilitiesError.timeout("Operation timed out after \(timeoutValue)s")
        }

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw TestUtilitiesError.unexpectedState("No result available")
        }
    }

    // MARK: - Memory Monitoring

    /// Log memory usage for debugging purposes
    public static func checkMemoryUsage(operation: String) {
        // Simple memory usage logging
        NSLog("🧠 Memory check after \(operation)")
    }
}

// MARK: - Error Types

public enum TestUtilitiesError: Error, LocalizedError {
    case timeout(String)
    case unexpectedState(String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let message), .unexpectedState(let message):
            return message
        }
    }
}
