import Foundation

/// ViewModel for managing workout entries and persistence
public class WorkoutViewModel: ObservableObject {
    @Published public var entries: [ExerciseEntry] = []
    private let dataStore: DataStoreProtocol

    public init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
        do {
            entries = try dataStore.load()
        } catch {
            // Log error and start with empty entries
            NSLog("Failed to load entries during initialization: \(error)")
            entries = []
        }
    }

    /// Adds a new exercise entry and persists data
    public func addEntry(_ entry: ExerciseEntry) {
        entries.append(entry)
        save()
    }

    /// Deletes entries at specified offsets and persists data
    public func deleteEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    /// Persists current entries to disk
    public func save() {
        do {
            try dataStore.save(entries: entries)
        } catch {
            // TODO: Proper error handling will be implemented in T004
            NSLog("Failed to save entries: \(error)")
        }
    }

    /// Returns a URL for sharing the entries as JSON
    public func exportJSON() -> URL? {
        do {
            return try dataStore.export(entries: entries)
        } catch {
            // Log error and return nil for compatibility
            NSLog("Failed to export entries: \(error)")
            return nil
        }
    }
}
