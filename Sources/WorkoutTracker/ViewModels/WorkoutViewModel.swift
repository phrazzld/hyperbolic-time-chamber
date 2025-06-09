import Foundation

/// ViewModel for managing workout entries and persistence
class WorkoutViewModel: ObservableObject {
    @Published var entries: [ExerciseEntry] = []
    private let dataStore: DataStore

    init(dataStore: DataStore = DataStore()) {
        self.dataStore = dataStore
        entries = dataStore.load()
    }

    /// Adds a new exercise entry and persists data
    func addEntry(_ entry: ExerciseEntry) {
        entries.append(entry)
        save()
    }

    /// Deletes entries at specified offsets and persists data
    func deleteEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    /// Persists current entries to disk
    func save() {
        dataStore.save(entries: entries)
    }

    /// Returns a URL for sharing the entries as JSON
    func exportJSON() -> URL? {
        dataStore.export(entries: entries)
    }
}
