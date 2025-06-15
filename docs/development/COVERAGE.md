# Test Coverage Guide

This document explains how to use the test coverage reporting system for the WorkoutTracker project.

## Quick Start

```bash
# Generate coverage report
./scripts/generate-coverage.sh

# View HTML report
open coverage/html/index.html
```

## Coverage Thresholds

The project maintains different coverage standards based on component type:

### Business Logic (90%+ required)
- **Models/** - Data structures (ExerciseEntry, ExerciseSet)
- **Services/** - Core business logic (DataStore)  
- **ViewModels/** - State management (WorkoutViewModel)

### Overall Project (Baseline maintenance)
- **Line Coverage**: ≥12% (current baseline: 12.26%)
- **Function Coverage**: ≥45% (current baseline: 47%)

### UI Components (Lower priority)
- **Views/** - SwiftUI views (0-20% acceptable, focus on ViewModels instead)
- **App.swift** - App entry point (minimal logic)

## Current Coverage Status

| Component | Line Coverage | Function Coverage | Status |
|-----------|---------------|-------------------|---------|
| Models/ExerciseEntry.swift | 100% | 100% | ✅ Excellent |
| Models/ExerciseSet.swift | 100% | 100% | ✅ Excellent |
| Services/DataStore.swift | 95.35% | 100% | ✅ Excellent |
| ViewModels/WorkoutViewModel.swift | 100% | 100% | ✅ Excellent |
| Views/AddEntryView.swift | 1.26% | 15% | ⚠️ Expected (UI) |
| Views/ContentView.swift | 0% | 0% | ⚠️ Expected (UI) |
| Views/HistoryView.swift | 0% | 0% | ⚠️ Expected (UI) |
| WorkoutTrackerApp.swift | 0% | 0% | ⚠️ Expected (Entry) |

## Generated Reports

The coverage script generates multiple output formats:

### 1. Text Summary (`coverage/coverage-summary.txt`)
- Overall coverage percentages
- Per-file breakdown
- Used for threshold validation

### 2. HTML Report (`coverage/html/index.html`)
- Interactive web interface
- Line-by-line coverage visualization
- Best for detailed analysis

### 3. JSON Data (`coverage/coverage.json`)
- Machine-readable format
- Used for programmatic analysis
- CI/CD integration

### 4. Badge Data (`coverage/coverage-badge.json`)
- Coverage badge information
- README badge generation
- Build status indicators

## CI/CD Integration

Coverage is automatically generated and validated in CI:

```yaml
# .github/workflows/ci.yml
- name: Run Tests with Coverage
  run: ./scripts/generate-coverage.sh

- name: Upload Coverage Reports
  uses: actions/upload-artifact@v3
  with:
    name: coverage-reports
    path: coverage/
```

## Local Development

### Running Coverage Locally

```bash
# Run tests with coverage
swift test --enable-code-coverage

# Generate full report
./scripts/generate-coverage.sh

# Quick coverage check
xcrun llvm-cov report .build/debug/WorkoutTracker \
  -instr-profile=.build/debug/codecov/default.profdata
```

### Adding Coverage for New Code

1. **Business Logic**: Aim for 95%+ coverage
   ```swift
   func testNewBusinessLogic() {
       // Comprehensive test coverage required
   }
   ```

2. **ViewModels**: Test all public methods
   ```swift
   func testViewModelBehavior() {
       // State changes, data flow, error handling
   }
   ```

3. **Views**: Focus on ViewModel integration
   ```swift
   func testViewModelIntegration() {
       // Test via ViewModel, not UI directly
   }
   ```

## Coverage Strategy

### What to Test (High Priority)
✅ **Models** - Data validation, encoding/decoding  
✅ **Services** - Business logic, persistence, error handling  
✅ **ViewModels** - State management, user interactions  
✅ **Integration** - End-to-end workflows  

### What Not to Test (Lower Priority)
⚠️ **SwiftUI Views** - UI testing is complex, focus on ViewModels  
⚠️ **App Entry Points** - Minimal logic, integration tests cover this  
⚠️ **Extensions** - Simple utilities, unless complex logic  

## Improving Coverage

### For Business Logic Components
1. Add unit tests for all public methods
2. Test error conditions and edge cases
3. Verify state changes and side effects
4. Test integration between components

### For the Overall Project
1. Focus on high-value, untested business logic
2. Add integration tests for complex workflows  
3. Consider property-based testing for models
4. Don't chase coverage in UI code

## Configuration

Coverage thresholds are configured in:
- `scripts/generate-coverage.sh` - Threshold values
- `.coveragerc` - Strategy documentation
- `.github/workflows/ci.yml` - CI integration

To adjust thresholds, edit the configuration section:

```bash
# Configuration - Set achievable baselines
MIN_LINE_COVERAGE=12
MIN_FUNCTION_COVERAGE=45
MIN_BUSINESS_LOGIC_COVERAGE=90
```

## Troubleshooting

### Coverage File Not Found
```bash
# Ensure tests run with coverage enabled
swift test --enable-code-coverage
```

### Low Coverage Warnings
- Focus on business logic first (Models/, Services/, ViewModels/)
- Don't worry about View coverage - test ViewModels instead
- Check HTML report for specific uncovered lines

### CI Coverage Failures
- Verify all tests pass locally with coverage
- Check that thresholds are realistic
- Review coverage artifacts in GitHub Actions

## Best Practices

1. **Test Business Logic First** - High-value, high-impact testing
2. **Maintain Current Coverage** - Don't let coverage decrease  
3. **Focus on Integration** - End-to-end workflows catch more bugs
4. **Use Coverage as a Guide** - Not a goal in itself
5. **Review HTML Reports** - Understand what's actually uncovered

For questions about coverage strategy or implementation, refer to the development philosophy documents or the team lead.