# CI Optimization Best Practices

This document provides guidelines for maintaining fast and reliable CI pipelines while ensuring comprehensive test coverage.

## Core Principles

1. **Fast Feedback Loop**: CI should complete within 3-5 minutes
2. **Environment-Aware Testing**: Tests should adapt to CI constraints
3. **Progressive Testing**: Run fast tests first, expensive tests later
4. **Fail Fast**: Stop execution on first failure to save resources

## Performance Test Guidelines

### 1. Dataset Size Management

**✅ DO:**
```swift
// Use environment detection for dataset sizing
private var isRunningInCI: Bool {
    ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
}

func testPerformance() {
    let entryCount = isRunningInCI ? 20 : 1000
    let dataset = generateDataset(count: entryCount)
    // ... test implementation
}
```

**❌ DON'T:**
```swift
// Fixed large datasets that timeout in CI
func testPerformance() {
    let dataset = generateDataset(count: 5000) // Too large for CI!
    // ... test implementation
}
```

### 2. Conditional Compilation for Stress Tests

**✅ DO:**
```swift
#if !CI_BUILD
func testExtremeScalability() {
    // Expensive stress test excluded from CI
    let hugeDataset = generateDataset(count: 10000)
    // ... stress test implementation
}
#endif
```

**Build Configuration:**
```bash
# CI builds/tests with CI_BUILD flag
swift test -Xswiftc -DCI_BUILD
```

### 3. Test Data Generation Optimization

**✅ DO:**
```swift
// Reuse test data generation
private lazy var sharedTestData: [TestModel] = generateTestData()

// Use simple, predictable data
private func generateTestData(count: Int) -> [TestModel] {
    (0..<count).map { TestModel(id: $0, name: "Test\($0)") }
}
```

**❌ DON'T:**
```swift
// Expensive random data generation in each test
func testSomething() {
    let data = (0..<1000).map { _ in 
        TestModel(
            id: UUID(),
            name: randomString(length: 100),
            data: randomData(size: 1024)
        )
    }
}
```

## File I/O Optimization

### 1. In-Memory Operations for CI

**✅ DO:**
```swift
class TestDataStore: DataStore {
    override init() {
        if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true" {
            // Use in-memory storage for CI
            super.init(inMemory: true)
        } else {
            // Use file-based storage for local testing
            super.init()
        }
    }
}
```

### 2. Minimize File Operations

**✅ DO:**
- Batch file operations
- Use temporary in-memory buffers
- Clean up test files immediately

**❌ DON'T:**
- Write large files repeatedly
- Leave test artifacts on disk
- Perform unnecessary file scans

## Test Organization

### 1. Test Categories

Organize tests by execution time:

```swift
// Fast tests (< 0.1s) - Always run
func testModelValidation() { }
func testSimpleCalculations() { }

// Medium tests (0.1s - 1s) - Run in CI with optimization
func testDataPersistence() { }
func testViewModelOperations() { }

// Slow tests (> 1s) - Consider CI exclusion or optimization
#if !CI_BUILD
func testLargeDatasetPerformance() { }
func testStressScenarios() { }
#endif
```

### 2. Test Parallelization

**CI Configuration:**
```yaml
# Use parallel execution for fast feedback
swift test --parallel

# Consider sequential for memory-constrained environments
swift test  # No --parallel flag
```

## CI-Specific Configurations

### 1. Timeout Configuration

```yaml
# GitHub Actions example
- name: Run Tests with Timeout
  run: |
    # Use gtimeout for test execution control
    gtimeout 180s swift test -Xswiftc -DCI_BUILD --parallel
```

### 2. Build Optimization

```bash
# Debug builds for CI (faster compilation)
swift build -c debug -Xswiftc -DCI_BUILD

# Release builds only for deployment
swift build -c release  # Only in release workflows
```

### 3. Dependency Caching

```yaml
# Cache Swift Package Manager dependencies
- uses: actions/cache@v4
  with:
    path: |
      .build
      SourcePackages
    key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift') }}
```

## Monitoring and Metrics

### 1. Track Key Metrics

Monitor these in every CI run:
- Total execution time
- Individual test suite times
- Memory usage peaks
- Test count changes

### 2. Performance Regression Detection

```swift
// Add performance baselines
func testPerformance() {
    measure {
        // Test code
    }
    // XCTest will warn if performance regresses > 10%
}
```

### 3. CI Performance Dashboard

Track trends over time:
- Average CI execution time
- Failure rate by test
- Timeout frequency
- Resource utilization

## Best Practices Checklist

Before adding new tests, verify:

- [ ] Dataset sizes are CI-aware (< 50 items for CI)
- [ ] Stress tests use `#if !CI_BUILD` conditional compilation
- [ ] File I/O is minimized or uses in-memory alternatives
- [ ] Test data generation is efficient and reusable
- [ ] Performance baselines are established
- [ ] Tests are categorized by execution time
- [ ] CI-specific optimizations are documented

## Common Pitfalls to Avoid

1. **Fixed Large Datasets**: Always use dynamic sizing based on environment
2. **Expensive Setup/Teardown**: Minimize repeated expensive operations
3. **File System Pollution**: Clean up test artifacts immediately
4. **Unbounded Loops**: Always set reasonable limits for iterations
5. **Network Dependencies**: Mock or stub external services
6. **Complex Test Data**: Use simple, predictable test data

## Migration Guide

When optimizing existing tests for CI:

1. **Identify Slow Tests**
   ```bash
   swift test --enable-test-discovery --verbose | grep "passed ("
   ```

2. **Apply Dataset Optimization**
   - Add `isRunningInCI` property
   - Implement conditional dataset sizing
   - Update assertions to use dynamic counts

3. **Extract Stress Tests**
   - Wrap in `#if !CI_BUILD`
   - Document why test is excluded from CI
   - Ensure core functionality is still tested

4. **Verify Optimizations**
   ```bash
   # Test with CI configuration locally
   GITHUB_ACTIONS=true swift test -Xswiftc -DCI_BUILD
   ```

## Continuous Improvement

1. **Regular Performance Reviews**: Monthly analysis of CI execution times
2. **Test Refactoring**: Continuously optimize slow tests
3. **Tool Updates**: Keep CI tools and dependencies current
4. **Feedback Loop**: Act on CI performance degradation immediately

Remember: The goal is fast, reliable CI that provides quick feedback without sacrificing essential test coverage.