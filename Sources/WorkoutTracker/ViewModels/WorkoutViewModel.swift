import Foundation

/// ViewModel for managing workout entries and persistence
public class WorkoutViewModel: ObservableObject {
    @Published public var entries: [ExerciseEntry] = []
    private let dataStore: DataStoreProtocol

    public init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
        entries = dataStore.load()
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
        dataStore.export(entries: entries)
    }
}
