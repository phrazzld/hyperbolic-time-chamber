# WorkoutTracker Documentation

Generated: 2025-06-10T17:11:06Z

## Overview

This documentation provides comprehensive API reference for the WorkoutTracker iOS application,
a SwiftUI-based workout tracking app with local data persistence and export capabilities.

## Documentation Stats

- **Swift Files**: 9
- **Documented Types**: 0
- **Documentation Comments**: 24

## Architecture

The app follows MVVM (Model-View-ViewModel) architecture:

- **Models**: Data structures (ExerciseEntry, ExerciseSet)
- **Views**: SwiftUI user interface components
- **ViewModels**: Business logic and state management
- **Services**: Data persistence and external integrations

## Browse Documentation

### Generated Documentation

- 📁 **Static HTML**: [Open Documentation](html/index.html)

### Quick Reference

**Core Types:**
- `ExerciseEntry`: Represents a complete exercise with multiple sets
- `ExerciseSet`: Individual set data (reps, weight, notes)
- `WorkoutViewModel`: Central state management and business logic
- `DataStore`: Local persistence and data export functionality

**Key Views:**
- `ContentView`: Main tab navigation interface
- `HistoryView`: Browse and manage past workout entries
- `AddEntryView`: Create new exercise entries with multiple sets
- `ActivityView`: iOS-specific sharing interface

## Development

### Generating Documentation Locally

```bash
# Generate all documentation
./scripts/generate-docs.sh

# Preview documentation (opens browser)
swift package --disable-sandbox preview-documentation --target WorkoutTracker
```

### Documentation Standards

- Use triple-slash (`///`) comments for public APIs
- Include usage examples for complex functions
- Document all public properties and methods
- Explain architectural patterns and design decisions

## Additional Documentation

- [CI Optimization Best Practices](CI-OPTIMIZATION-BEST-PRACTICES.md) - Guidelines for maintaining fast CI pipelines
- [CLAUDE.md](../CLAUDE.md) - Developer guide and CI troubleshooting

---

*Documentation generated using Swift-DocC*
