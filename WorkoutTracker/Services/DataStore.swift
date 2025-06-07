import Foundation

/// Handles persistence of exercise entries to local storage
class DataStore {
    private let fileName = "workout_entries.json"

    private var fileURL: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent(fileName)
    }

    /// Loads saved entries from disk, or returns an empty list
    func load() -> [ExerciseEntry] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ExerciseEntry].self, from: data)) ?? []
    }

    /// Saves entries to disk in JSON format
    func save(entries: [ExerciseEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomicWrite)
    }

    /// Exports entries to a shareable JSON file and returns its URL
    func export(entries: [ExerciseEntry]) -> URL? {
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