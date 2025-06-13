# Test Configuration System

This module provides centralized configuration for test execution with environment-specific settings.

## Overview

The Test Configuration system allows tests to automatically adapt their behavior based on the execution environment (CI vs local development). This ensures fast CI pipelines while maintaining comprehensive testing capabilities locally.

## Features

- **Environment Detection**: Automatic detection of CI vs local development
- **Dynamic Dataset Sizing**: Configurable dataset sizes for different test scenarios
- **Timeout Management**: Environment-specific timeout configurations
- **Test Categories**: Organized test execution by category (unit, integration, performance, stress)
- **Performance Optimization**: In-memory storage for CI, file-based for local
- **Execution Monitoring**: Test execution time tracking and warnings

## Usage

### 1. Basic Usage with ConfigurableTestCase

```swift
import XCTest
import TestConfiguration
@testable import WorkoutTracker

final class MyTests: ConfigurableTestCase {
    func testExample() {
        // Access configuration
        let dataSize = config.mediumDatasetSize
        print("Using dataset size: \(dataSize)")
        
        // Use environment-aware measurement
        measureWithConfig {
            // Performance test code
        }
    }
}
```

### 2. Using Test Categories

```swift
// Unit tests (always run)
final class MyUnitTests: UnitTestCase {
    func testBasicLogic() {
        // Fast unit test
    }
}

// Performance tests (run with adjusted datasets)
final class MyPerformanceTests: PerformanceTestCase {
    func testLargeOperation() {
        let size = config.largeDatasetSize
        // Performance test with environment-specific sizing
    }
}

// Stress tests (skip in CI)
final class MyStressTests: StressTestCase {
    func testExtremeLoad() throws {
        // Automatically skipped in CI
        let size = config.stressDatasetSize
        // Extreme stress test
    }
}
```

### 3. Conditional Test Execution

```swift
func testCIOnly() throws {
    try skipIfLocal("This test only runs in CI")
    // CI-specific test logic
}

func testLocalOnly() throws {
    try skipIfCI("This test only runs locally")
    // Local-only test logic
}
```

### 4. Dataset Size Management

```swift
func testWithDynamicDataset() {
    // Use predefined categories
    let smallSize = datasetSize(for: .small)     // 20 in CI, 100 locally
    let mediumSize = datasetSize(for: .medium)   // 30 in CI, 500 locally
    let largeSize = datasetSize(for: .large)     // 50 in CI, 1000 locally
    
    // Log dataset usage
    logDatasetSize(largeSize, for: "performance test")
}
```

## Configuration Files

### ci-config.json
Configuration for CI environments with reduced dataset sizes and shorter timeouts.

### local-config.json
Configuration for local development with full dataset sizes and extended timeouts.

## Environment Variables

- `GITHUB_ACTIONS`: Set to "true" in GitHub Actions CI
- `CI_BUILD`: Alternative CI detection flag

## Best Practices

1. **Inherit from appropriate base class**: Use `UnitTestCase`, `IntegrationTestCase`, `PerformanceTestCase`, or `StressTestCase`
2. **Use configuration for dataset sizes**: Never hardcode dataset sizes
3. **Log important metrics**: Use `logDatasetSize()` for transparency
4. **Handle timeouts gracefully**: Use `executeWithTimeout()` for async operations
5. **Monitor test execution**: Tests exceeding warning thresholds are logged

## Migration Guide

### Before (Hardcoded):
```swift
func testPerformance() {
    let entryCount = isRunningInCI ? 50 : 1000
    measure {
        // Test code
    }
}
```

### After (Configuration-based):
```swift
final class MyTests: PerformanceTestCase {
    func testPerformance() {
        let entryCount = config.largeDatasetSize
        measureWithConfig {
            // Test code
        }
    }
}
```

## Extending the Configuration

To add new configuration parameters:

1. Add properties to `TestConfiguration.swift`
2. Update JSON configuration files
3. Document new parameters in this README