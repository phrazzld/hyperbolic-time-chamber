import Foundation

/// In-memory implementation of DataStoreProtocol for testing and preview purposes
public class InMemoryDataStore: DataStoreProtocol {
    private var entries: [ExerciseEntry]

    public init(entries: [ExerciseEntry] = []) {
        self.entries = entries
    }

    public func load() -> [ExerciseEntry] {
        entries
    }

    public func save(entries: [ExerciseEntry]) throws {
        self.entries = entries
    }

    public func export(entries: [ExerciseEntry]) -> URL? {
        // Create a temporary file for in-memory store exports
        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("workout_entries_export_\(UUID().uuidString).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(entries) else { return nil }

        do {
            try data.write(to: exportURL, options: .atomicWrite)
            return exportURL
        } catch {
            return nil
        }
    }
}
