import Foundation

/// Handles persistence of exercise entries to local file storage
public class FileDataStore: DataStoreProtocol {
    private let fileName: String
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(fileManager: FileManager = .default, baseDirectory: URL? = nil, fileName: String = "workout_entries.json") {
        self.fileManager = fileManager
        self.fileName = fileName
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            self.baseDirectory = urls[0]
        }
    }

    private var fileURL: URL {
        baseDirectory.appendingPathComponent(fileName)
    }

    /// Loads saved entries from disk, or returns an empty list
    public func load() -> [ExerciseEntry] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ExerciseEntry].self, from: data)) ?? []
    }

    /// Saves entries to disk in JSON format
    public func save(entries: [ExerciseEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomicWrite)
    }

    /// Exports entries to a shareable JSON file and returns its URL
    public func export(entries: [ExerciseEntry]) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return nil }
        let exportURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("workout_entries_export.json")
        do {
            try data.write(to: exportURL, options: .atomicWrite)
            return exportURL
        } catch {
            return nil
        }
    }
}
