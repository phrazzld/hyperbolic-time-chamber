import Foundation

/// Errors that can occur during data store operations
public enum DataStoreError: Error, LocalizedError {
    case saveFailed(underlyingError: Error)
    case loadFailed(underlyingError: Error)
    case exportFailed(reason: String)
    case invalidFileName(reason: String)
    case pathTraversalAttempt(fileName: String)
    case insufficientPermissions(path: String)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load data: \(error.localizedDescription)"
        case .exportFailed(let reason):
            return "Failed to export data: \(reason)"
        case .invalidFileName(let reason):
            return "Invalid file name: \(reason)"
        case .pathTraversalAttempt:
            return "Path traversal attempt detected in file name"
        case .insufficientPermissions(let path):
            return "Insufficient permissions for file operations at path: \(path)"
        }
    }
}

/// Protocol defining the interface for workout data persistence
public protocol DataStoreProtocol {
    /// Loads saved entries from storage
    func load(correlationId: String?) throws -> [ExerciseEntry]

    /// Saves entries to storage
    func save(entries: [ExerciseEntry], correlationId: String?) throws

    /// Exports entries to a shareable format and returns its URL
    func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL
}

/// Extension providing default implementations with auto-generated correlation IDs
public extension DataStoreProtocol {
    /// Loads saved entries from storage with auto-generated correlation ID
    func load() throws -> [ExerciseEntry] {
        try load(correlationId: UUID().uuidString)
    }

    /// Saves entries to storage with auto-generated correlation ID
    func save(entries: [ExerciseEntry]) throws {
        try save(entries: entries, correlationId: UUID().uuidString)
    }

    /// Exports entries with auto-generated correlation ID
    func export(entries: [ExerciseEntry]) throws -> URL {
        try export(entries: entries, correlationId: UUID().uuidString)
    }
}
