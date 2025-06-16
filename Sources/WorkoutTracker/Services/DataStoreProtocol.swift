import Foundation

/// Protocol defining the interface for workout data persistence
public protocol DataStoreProtocol {
    /// Loads saved entries from storage
    func load() -> [ExerciseEntry]

    /// Saves entries to storage
    func save(entries: [ExerciseEntry]) throws

    /// Exports entries to a shareable format and returns its URL
    func export(entries: [ExerciseEntry]) -> URL?
}
