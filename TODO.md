# TODO: Dependency Injection Implementation

## Phase 1: Core Abstractions (60 minutes)

- [x] **T001 · Feature · P0**: Create DataStoreProtocol.swift
    - **Context:** Foundation for all dependency injection
    - **Action:**
        1. Create `DataStoreProtocol.swift` with public protocol definition
        2. Define methods: `load() -> [ExerciseEntry]`, `save(entries: [ExerciseEntry]) throws`, `export(entries: [ExerciseEntry]) -> URL?`
    - **Done‑when:**
        1. Protocol file exists and compiles successfully
        2. Protocol defines clean contract for data persistence operations
    - **Depends‑on:** none

- [x] **T002 · Refactor · P0**: Update access modifiers for domain models
    - **Context:** Enable external module access to domain types
    - **Action:**
        1. Make `ExerciseEntry` and `ExerciseSet` structs public
        2. Add public initializers to allow instantiation from other modules
    - **Done‑when:**
        1. Domain models are accessible and instantiable from external modules
        2. No compilation errors in modules using these types
    - **Depends‑on:** none

## Phase 2: Infrastructure Refactoring (75 minutes)

- [x] **T003 · Refactor · P0**: Refactor DataStore to FileDataStore with protocol conformance
    - **Context:** Production implementation with configurable dependencies
    - **Action:**
        1. Rename `DataStore.swift` to `FileDataStore.swift`
        2. Conform `FileDataStore` class to `DataStoreProtocol`
        3. Add configurable `fileName: String` parameter to initializer
        4. Make class and protocol methods public
    - **Done‑when:**
        1. FileDataStore correctly implements all methods of DataStoreProtocol
        2. File name for persistence can be set via initializer
        3. Project compiles successfully
    - **Depends‑on:** [T001, T002]

- [ ] **T004 · Refactor · P1**: Implement explicit error types for FileDataStore
    - **Context:** Replace silent failures with proper error handling
    - **Action:**
        1. Define `DataStoreError` enum with cases: `saveFailed(underlyingError: Error)`, `loadFailed(underlyingError: Error)`, `exportFailed(reason: String)`
        2. Update `save` method to throw `DataStoreError` instead of using `try?`
        3. Update all call sites to handle thrown errors
    - **Done‑when:**
        1. Save method no longer silently fails
        2. Method signature updated to `throws`
        3. All error cases properly handled
    - **Depends‑on:** [T003]

## Phase 3: Test Infrastructure (45 minutes)

- [x] **T005 · Feature · P0**: Implement InMemoryDataStore for testing
    - **Context:** Fast, reliable testing without file system dependencies
    - **Action:**
        1. Create `InMemoryDataStore.swift` implementing `DataStoreProtocol`
        2. Store `[ExerciseEntry]` in memory array
        3. Add public initializer accepting optional array of entries for preloading
        4. Implement export method creating temporary files (maintains protocol contract)
    - **Done‑when:**
        1. InMemoryDataStore correctly implements all DataStoreProtocol methods
        2. Class can be initialized with pre-set data for testing
        3. Export functionality works identically to FileDataStore
    - **Depends‑on:** [T001, T002]

- [ ] **T006 · Test · P1**: Add comprehensive unit tests for InMemoryDataStore
    - **Context:** Verify test implementation reliability
    - **Action:**
        1. Create `InMemoryDataStoreTests.swift`
        2. Write unit tests for `load`, `save`, and `export` functionality
        3. Test edge cases: empty data, multiple save/load cycles, export of empty data
        4. Verify protocol compliance
    - **Done‑when:**
        1. All tests for InMemoryDataStore pass
        2. Test coverage >95% for InMemoryDataStore
        3. Edge cases properly covered
    - **Depends‑on:** [T005]

## Phase 4: Dependency Injection (90 minutes)

- [ ] **T007 · Refactor · P0**: Update WorkoutViewModel for dependency injection
    - **Context:** Enable environment-aware ViewModel construction
    - **Action:**
        1. Update `WorkoutViewModel` initializer to accept `DataStoreProtocol` parameter
        2. Remove hardcoded `DataStore()` instantiation inside ViewModel
        3. Make ViewModel class and initializer public
    - **Done‑when:**
        1. WorkoutViewModel no longer has direct dependency on concrete DataStore
        2. Project compiles successfully
        3. ViewModel can be constructed with any DataStoreProtocol implementation
    - **Depends‑on:** [T001]

- [ ] **T008 · Feature · P0**: Create DependencyFactory for environment-aware dependency creation
    - **Context:** Centralized dependency creation with environment detection
    - **Action:**
        1. Create `DependencyFactory.swift`
        2. Implement `AppEnvironment` enum (production, testing, demo)
        3. Add `createViewModel(for:)` factory method
        4. Add automatic environment detection logic
        5. Return appropriate DataStore implementation based on environment
    - **Done‑when:**
        1. Factory can provide production DataStoreProtocol instance (FileDataStore)
        2. Factory can provide test DataStoreProtocol instance (InMemoryDataStore)
        3. Environment detection works correctly
    - **Depends‑on:** [T003, T005, T007]

- [ ] **T009 · Refactor · P0**: Update WorkoutTrackerApp to use DependencyFactory
    - **Context:** Wire up dependency injection at app entry point
    - **Action:**
        1. Update `WorkoutTrackerApp.swift` to use `DependencyFactory.createViewModel()`
        2. Remove any hardcoded dependency creation
        3. Ensure automatic environment detection works for screenshot/demo modes
    - **Done‑when:**
        1. App runs correctly using dependency-injected ViewModel
        2. No hardcoded dependencies remain in app entry point
        3. App uses correct DataStore implementation for current environment
    - **Depends‑on:** [T008]

## Phase 5: Test Migration (60 minutes)

- [ ] **T010 · Refactor · P0**: Refactor existing tests to use InMemoryDataStore
    - **Context:** Eliminate file system dependencies from test suite
    - **Action:**
        1. Update `WorkoutViewModelTests.swift` to initialize ViewModel with InMemoryDataStore
        2. Preload InMemoryDataStore with specific test data for each test case
        3. Remove all file system interactions and cleanup code from tests
        4. Measure and verify test execution speed improvement
    - **Done‑when:**
        1. All WorkoutViewModel tests pass without accessing file system
        2. Test execution speed improved by 50%+
        3. No file I/O operations in unit tests
    - **Depends‑on:** [T005, T007]

- [ ] **T011 · Test · P1**: Add dependency injection tests for DependencyFactory
    - **Context:** Verify factory configuration and environment detection
    - **Action:**
        1. Create `DependencyFactoryTests.swift`
        2. Write tests verifying factory returns correct implementation for different environments
        3. Test custom implementation injection patterns
        4. Verify environment detection logic
    - **Done‑when:**
        1. All DependencyFactory tests pass
        2. Environment detection verified for all scenarios
        3. Custom implementation patterns documented
    - **Depends‑on:** [T008]

## Observability & Future-Proofing (Optional Enhancements)

- [ ] **T012 · Feature · P2**: Implement structured logging in FileDataStore
    - **Context:** Enable production debugging and monitoring
    - **Action:**
        1. Add structured logging to all FileDataStore operations (load, save, export)
        2. Include metadata: source, fileName, entryCount, correlationId
        3. Use JSON format for queryable logs
    - **Done‑when:**
        1. FileDataStore operations produce structured, queryable logs
        2. All operations include relevant metadata
    - **Depends‑on:** [T004]

- [ ] **T013 · Feature · P2**: Add correlation ID propagation through DataStore operations
    - **Context:** Enable request tracing across operations
    - **Action:**
        1. Update DataStoreProtocol methods to accept optional correlationID parameter
        2. Update FileDataStore and InMemoryDataStore to include ID in log entries
        3. Generate correlation ID at app startup and propagate through operations
    - **Done‑when:**
        1. All log entries from DataStore include correlation ID
        2. Related operations can be traced using consistent ID
    - **Depends‑on:** [T012]

- [ ] **T014 · Security · P2**: Implement security hardening for file operations
    - **Context:** Prevent path traversal and permission issues
    - **Action:**
        1. Add input validation for configurable file names in FileDataStore
        2. Sanitize file paths to prevent traversal vulnerabilities
        3. Add permission checks before file operations
    - **Done‑when:**
        1. Invalid file names handled gracefully and securely
        2. Path traversal attacks prevented
        3. Permission errors handled gracefully
    - **Depends‑on:** [T003]

## Documentation & Knowledge Sharing

- [ ] **T015 · Documentation · P2**: Document dependency injection patterns in DEVELOPMENT_GUIDE.md
    - **Context:** Enable team understanding and future development
    - **Action:**
        1. Add new section explaining DI pattern, DependencyFactory, and protocol-based testing
        2. Include practical code examples showing ViewModel construction with different DataStores
        3. Document best practices for adding new injectable dependencies
    - **Done‑when:**
        1. Development guide updated with comprehensive DI documentation
        2. Clear examples available for future dependency additions
    - **Depends‑on:** [T009, T011]

- [ ] **T016 · Documentation · P3**: Update onboarding documentation with DI examples
    - **Context:** Smooth onboarding for new team members
    - **Action:**
        1. Review existing onboarding materials
        2. Add section explaining new DI architecture
        3. Include setup instructions for local development with different environments
    - **Done‑when:**
        1. Onboarding documentation reflects new DI system
        2. New developers can understand and work with DI patterns
    - **Depends‑on:** [T015]

- [ ] **T017 · Planning · P3**: Create follow-up issue for app modularization
    - **Context:** Plan next phase building on DI foundation
    - **Action:**
        1. Create new issue titled "Plan App Modularization (Post-DI)"
        2. Reference this DI implementation as prerequisite
        3. Outline how DI enables clean module boundaries
    - **Done‑when:**
        1. Issue #20 (or equivalent) created with appropriate context
        2. Clear connection established between DI and modularization
    - **Depends‑on:** [T009]

- [ ] **T018 · Planning · P3**: Create follow-up issue for additional DataStore adapters
    - **Context:** Plan future storage backend options
    - **Action:**
        1. Create new issue titled "Investigate Future DataStore Adapters"
        2. List potential adapters: CloudKit, Core Data, remote APIs
        3. Document how protocol-based design enables easy adapter addition
    - **Done‑when:**
        1. New issue created with comprehensive adapter analysis
        2. Clear roadmap for storage backend expansion
    - **Depends‑on:** [T009]

## Quality Gates & Verification

- [ ] **QG001 · Quality Gate**: Audit current test coverage before refactoring
    - **Context:** Ensure existing functionality is protected during refactoring
    - **Action:**
        1. Generate test coverage report for DataStore and WorkoutViewModel
        2. Identify gaps in coverage for critical paths (load, save, add, delete)
        3. Add missing tests to achieve >90% coverage
    - **Done‑when:**
        1. Test coverage report shows >90% for DataStore and WorkoutViewModel
        2. All critical functionality covered by tests
        3. Test suite passes reliably in CI
    - **Depends‑on:** none

- [ ] **QG002 · Quality Gate**: Verify no breaking changes to existing functionality
    - **Context:** Ensure refactoring maintains backward compatibility
    - **Action:**
        1. Run complete test suite after each major change
        2. Manual verification in simulator for core user workflows
        3. Verify data persistence works correctly with new architecture
    - **Done‑when:**
        1. All existing tests continue to pass
        2. Core user workflows verified manually
        3. No regression in app functionality
    - **Depends‑on:** [T009]

- [ ] **QG003 · Quality Gate**: Measure and verify test performance improvement
    - **Context:** Confirm DI implementation delivers promised benefits
    - **Action:**
        1. Measure test execution time before and after InMemoryDataStore migration
        2. Verify 50%+ improvement in test speed
        3. Confirm no file I/O operations in unit tests
    - **Done‑when:**
        1. Test execution speed improved by 50%+
        2. No file system access detected in unit tests
        3. Performance improvement documented
    - **Depends‑on:** [T010]

---

## Success Metrics

- ✅ Zero file system access in unit tests
- ✅ 50%+ improvement in test execution speed  
- ✅ Clean separation: domain logic independent of infrastructure
- ✅ Environment-aware dependency creation working correctly
- ✅ No breaking changes to existing functionality
- ✅ Clear examples and documentation for future dependency additions

## Critical Path Summary

```
T001 (Protocol) → T003 (FileDataStore) → T007 (ViewModel) → T008 (Factory) → T009 (App)
                ↓
                T005 (InMemoryDataStore) → T010 (Test Migration)
```

**Total Estimated Time: 4.5 hours for critical path + optional enhancements as time permits**