# Task Description

## Issue Details
Issue #18: Implement proper dependency injection for DataStore and FileManager
URL: https://github.com/phrazzld/hyperbolic-time-chamber/issues/18

## Overview
The codebase currently lacks proper dependency injection, violating the core principle of "Design for Testability". DataStore hardcodes FileManager and file paths, WorkoutViewModel creates its own DataStore instance, and there's no way to inject test doubles or alternate implementations. This forces tests to use real file system access, making them slower and less reliable.

## Requirements
- Define protocol abstractions for DataStore and FileManager
- Implement constructor-based dependency injection
- Remove all hardcoded dependencies and file paths
- Enable testing without file system access
- Update app initialization to support dependency injection
- Maintain backward compatibility with existing functionality

## Technical Context
The current implementation has several anti-patterns:
- `DataStore` directly instantiates `FileManager.default` and hardcodes "workout_entries.json"
- `WorkoutViewModel` creates its own `DataStore` instance internally
- Tests must access the real file system, making them brittle and slow
- No abstraction layer between business logic and infrastructure

This violates key leyline principles:
- Dependency Inversion: High-level modules depend on low-level details
- Testability: Cannot test without real infrastructure
- Explicit Dependencies: Dependencies are created internally rather than injected

## Related Issues
- Blocks: Issue #20 (Break up monolithic package into separate modules)
- Blocks: Proper unit testing capabilities
- Enables: Issue #19 (Simplify test configuration to essential parameters only)
- Related to: Issue #16 (Remove @testable imports and design proper public APIs)