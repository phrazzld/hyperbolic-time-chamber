# Plan Details

# Implementation Plan: Dependency Injection for DataStore and FileManager

## Architecture Blueprint

### Overview
Implement dependency injection using protocol abstractions and factory pattern, enabling testable, modular code while maintaining simplicity.

### Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                        App Layer                             │
│  ┌─────────────────┐        ┌──────────────────────────┐  │
│  │WorkoutTrackerApp│───────▶│   DependencyFactory      │  │
│  └─────────────────┘        └──────────────────────────┘  │
│                                         │                    │
│                                         ▼                    │
│  ┌─────────────────────────────────────────────────────┐  │
│  │                  WorkoutViewModel                    │  │
│  │              (Depends on DataStoreProtocol)         │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              DataStoreProtocol                      │  │
│  │  - load() -> [ExerciseEntry]                       │  │
│  │  - save(entries: [ExerciseEntry]) throws           │  │
│  │  - export(entries: [ExerciseEntry]) -> URL?        │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   Infrastructure Layer    │    │      Test Layer          │
│ ┌──────────────────────┐ │    │ ┌──────────────────────┐ │
│ │   FileDataStore      │ │    │ │  InMemoryDataStore   │ │
│ │ (Production impl)    │ │    │ │   (Test impl)        │ │
│ └──────────────────────┘ │    │ └──────────────────────┘ │
└──────────────────────────┘    └──────────────────────────┘
```

### Design Decisions

1. **Protocol-Based Abstraction**: Define `DataStoreProtocol` as the contract between domain and infrastructure
2. **Factory Pattern**: Use `DependencyFactory` for environment-aware dependency creation
3. **Constructor Injection**: All dependencies explicitly passed through initializers
4. **No FileManager Protocol**: After analysis, FileManager abstraction adds unnecessary complexity for current needs
5. **Configurable File Paths**: Support custom file names through constructor parameters

## Implementation Steps

### Phase 1: Create Protocol Abstractions (30 min)

1. **Create `DataStoreProtocol.swift`**
   ```swift
   public protocol DataStoreProtocol {
       func load() -> [ExerciseEntry]
       func save(entries: [ExerciseEntry]) throws
       func export(entries: [ExerciseEntry]) -> URL?
   }
   ```

2. **Update access modifiers**
   - Make `ExerciseEntry` and `ExerciseSet` public
   - Add public initializers where needed

### Phase 2: Refactor Existing Implementation (45 min)

1. **Update `DataStore.swift`**
   - Conform to `DataStoreProtocol`
   - Add configurable file name parameter
   - Make class and methods public
   - Keep existing implementation logic unchanged

2. **Refactor error handling**
   - Define proper error types for save operations
   - Remove silent failures (try?)

### Phase 3: Create Test Implementation (45 min)

1. **Implement `InMemoryDataStore.swift`**
   - Store data in memory array
   - Implement all protocol methods
   - Support preloading test data
   - Export creates temporary files for testing

2. **Add comprehensive tests**
   - Unit tests for InMemoryDataStore
   - Verify protocol compliance

### Phase 4: Implement Dependency Injection (1 hour)

1. **Update `WorkoutViewModel.swift`**
   - Accept `DataStoreProtocol` in initializer
   - Remove hardcoded DataStore creation
   - Make class public for external instantiation

2. **Create `DependencyFactory.swift`**
   - Environment detection (demo, test, production)
   - Factory methods for creating dependencies
   - Configuration struct for different environments

3. **Update `WorkoutTrackerApp.swift`**
   - Use DependencyFactory to create dependencies
   - Pass dependencies through environment or initializers

### Phase 5: Update Tests (1.5 hours)

1. **Refactor existing tests**
   - Use InMemoryDataStore instead of file-based
   - Remove file system cleanup code
   - Improve test speed and reliability

2. **Add dependency injection tests**
   - Test factory configuration
   - Verify environment detection
   - Test custom implementations

3. **Create example test patterns**
   - Document best practices for mocking
   - Show how to test with different implementations

## Testing Strategy

### Unit Testing Approach
- **No internal mocking**: Use real implementations or in-memory variants
- **Protocol verification**: Ensure all implementations satisfy contract
- **Isolated testing**: Each component tested independently
- **Fast execution**: No file I/O in unit tests

### Test Layers
1. **Protocol Compliance Tests**: Verify all implementations satisfy DataStoreProtocol
2. **Component Tests**: Test each implementation in isolation
3. **Integration Tests**: Test ViewModel with different DataStore implementations
4. **Configuration Tests**: Verify DependencyFactory creates correct dependencies

### Test Data Management
- Use factory methods for consistent test data
- Leverage `WorkoutTestDataFactory` for realistic data
- Keep test data minimal but representative

## Logging & Observability

### Structured Logging Implementation
```swift
// In DataStore operations
logger.info("Loading workout entries", 
    metadata: ["source": "file", "fileName": fileName])

logger.error("Failed to save entries", 
    metadata: ["error": error.localizedDescription, "entryCount": entries.count])
```

### Correlation ID Flow
- Generate at app startup
- Pass through all DataStore operations
- Include in all log entries
- Enable request tracing

## Security & Configuration

### Security Considerations
- No hardcoded file paths
- Validate file permissions before operations
- Sanitize file names from configuration
- No sensitive data in logs

### Configuration Management
- File paths configurable through DependencyFactory
- Environment-based configuration selection
- Support for feature flags (future)
- No configuration in source code

## Risk Analysis

### Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Breaking existing functionality | High | Comprehensive test coverage before refactoring |
| Performance regression | Low | InMemory implementation likely faster |
| Complex migration | Medium | Incremental approach, maintain compatibility |
| Test brittleness | Low | Removing file I/O makes tests more stable |

### Implementation Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Scope creep | Medium | Stick to minimal viable DI implementation |
| Over-engineering | Medium | Apply YAGNI, avoid unnecessary abstractions |
| Public API design issues | High | Review against leyline principles |
| Merge conflicts | Low | Complete in single focused session |

## Success Metrics

1. **All tests pass without file system access**
2. **No hardcoded dependencies in business logic**
3. **Clean separation between domain and infrastructure**
4. **Improved test execution speed (target: 50% faster)**
5. **Zero breaking changes to existing functionality**
6. **Clear examples for future dependency additions**

## Open Questions

1. **FileManager abstraction**: Current analysis suggests it's unnecessary complexity. Confirm?
2. **Migration strategy**: Should we support gradual migration or convert all at once?
3. **Export functionality**: Should InMemoryDataStore create real files for export or return mock URLs?
4. **Error handling**: Standardize on throwing vs returning optionals?

## Next Steps After Implementation

1. Document dependency injection patterns in DEVELOPMENT_GUIDE.md
2. Update onboarding documentation with DI examples
3. Plan modularization (Issue #20) building on DI foundation
4. Consider adding more infrastructure adapters (CloudKit, Core Data)

## Time Estimate

- Phase 1: 30 minutes
- Phase 2: 45 minutes  
- Phase 3: 45 minutes
- Phase 4: 1 hour
- Phase 5: 1.5 hours
- **Total: ~4.5 hours**

This plan delivers practical value by enabling proper testing while avoiding over-engineering, perfectly aligned with the project's emphasis on simplicity and testability.

## Task Breakdown Requirements
- Create atomic, independent tasks
- Ensure proper dependency mapping
- Include verification steps
- Follow project task ID and formatting conventions
