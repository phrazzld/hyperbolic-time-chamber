import Foundation

/// In-memory implementation of DataStoreProtocol for testing and preview purposes
public class InMemoryDataStore: DataStoreProtocol {
    private var entries: [ExerciseEntry]

    public init(entries: [ExerciseEntry] = []) {
        self.entries = entries
    }

    public func load(correlationId: String?) throws -> [ExerciseEntry] {
        entries
    }

    public func save(entries: [ExerciseEntry], correlationId: String?) throws {
        self.entries = entries
    }

    public func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL {
        // Create a temporary file for in-memory store exports
        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("workout_entries_export_\(UUID().uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: exportURL, options: .atomicWrite)
            return exportURL
        } catch {
            throw DataStoreError.exportFailed(reason: error.localizedDescription)
        }
    }
}
