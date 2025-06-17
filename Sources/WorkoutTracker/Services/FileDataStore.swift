import Foundation
import os

/// Handles persistence of exercise entries to local file storage
public class FileDataStore: DataStoreProtocol {
    private let fileName: String
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        fileName: String = "workout_entries.json"
    ) throws {
        // Validate file name for security
        try Self.validateFileName(fileName)

        self.fileManager = fileManager
        self.fileName = fileName

        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            self.baseDirectory = urls[0]
        }

        // Validate directory permissions
        try validateDirectoryPermissions()
    }

    private var fileURL: URL {
        baseDirectory.appendingPathComponent(fileName)
    }

    /// Logs structured data in JSON format for production monitoring
    private func logOperation(
        operation: String,
        status: String,
        entryCount: Int? = nil,
        correlationId: String = UUID().uuidString,
        additionalInfo: [String: Any] = [:]
    ) {
        var logData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "FileDataStore",
            "operation": operation,
            "status": status,
            "fileName": fileName,
            "correlationId": correlationId
        ]

        if let entryCount = entryCount {
            logData["entryCount"] = entryCount
        }

        // Add any additional information
        for (key, value) in additionalInfo {
            logData[key] = value
        }

        // Convert to JSON and log
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NSLog("STRUCTURED_LOG: %@", jsonString)
        }
    }

    /// Loads saved entries from disk
    public func load(correlationId: String?) throws -> [ExerciseEntry] {
        let corrId = correlationId ?? UUID().uuidString
        logOperation(operation: "load", status: "started", correlationId: corrId)

        // If file doesn't exist, return empty array (not an error)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logOperation(
                operation: "load",
                status: "completed",
                entryCount: 0,
                correlationId: corrId,
                additionalInfo: ["reason": "file_not_found"]
            )
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([ExerciseEntry].self, from: data)
            logOperation(operation: "load", status: "completed", entryCount: entries.count, correlationId: corrId)
            return entries
        } catch {
            logOperation(
                operation: "load",
                status: "failed",
                correlationId: corrId,
                additionalInfo: ["error": error.localizedDescription]
            )
            throw DataStoreError.loadFailed(underlyingError: error)
        }
    }

    /// Saves entries to disk in JSON format
    public func save(entries: [ExerciseEntry], correlationId: String?) throws {
        let corrId = correlationId ?? UUID().uuidString
        logOperation(operation: "save", status: "started", entryCount: entries.count, correlationId: corrId)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomicWrite)
            logOperation(operation: "save", status: "completed", entryCount: entries.count, correlationId: corrId)
        } catch {
            logOperation(
                operation: "save",
                status: "failed",
                entryCount: entries.count,
                correlationId: corrId,
                additionalInfo: ["error": error.localizedDescription]
            )
            throw DataStoreError.saveFailed(underlyingError: error)
        }
    }

    /// Exports entries to a shareable JSON file and returns its URL
    public func export(entries: [ExerciseEntry], correlationId: String?) throws -> URL {
        let corrId = correlationId ?? UUID().uuidString
        logOperation(operation: "export", status: "started", entryCount: entries.count, correlationId: corrId)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            let exportURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("workout_entries_export.json")
            try data.write(to: exportURL, options: .atomicWrite)
            logOperation(
                operation: "export",
                status: "completed",
                entryCount: entries.count,
                correlationId: corrId,
                additionalInfo: ["exportPath": exportURL.path]
            )
            return exportURL
        } catch {
            logOperation(
                operation: "export",
                status: "failed",
                entryCount: entries.count,
                correlationId: corrId,
                additionalInfo: ["error": error.localizedDescription]
            )
            throw DataStoreError.exportFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Security Validation Methods

    /// Validates file name for security to prevent path traversal and invalid characters
    private static func validateFileName(_ fileName: String) throws {
        try validateFileNameBasics(fileName)
        try validatePathTraversal(fileName)
        try validateCharacters(fileName)
        try validateReservedNames(fileName)
    }

    /// Validates basic file name requirements
    private static func validateFileNameBasics(_ fileName: String) throws {
        // Check for empty or whitespace-only names
        guard !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DataStoreError.invalidFileName(reason: "File name cannot be empty or whitespace only")
        }

        // Check file name length (255 characters is common filesystem limit)
        if fileName.count > 255 {
            throw DataStoreError.invalidFileName(reason: "File name is too long")
        }
    }

    /// Validates against path traversal attempts
    private static func validatePathTraversal(_ fileName: String) throws {
        // Check for path traversal attempts
        let pathTraversalPatterns = ["../", "..\\", "/", "\\"]
        for pattern in pathTraversalPatterns where fileName.contains(pattern) {
            throw DataStoreError.pathTraversalAttempt(fileName: fileName)
        }

        // Check for absolute path attempts
        if fileName.hasPrefix("/") || fileName.hasPrefix("\\") {
            throw DataStoreError.pathTraversalAttempt(fileName: fileName)
        }
    }

    /// Validates against invalid characters
    private static func validateCharacters(_ fileName: String) throws {
        // Check for invalid characters (cross-platform)
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
        if fileName.rangeOfCharacter(from: invalidCharacters) != nil {
            throw DataStoreError.invalidFileName(reason: "File name contains invalid characters")
        }

        // Check for control characters and newlines
        let controlCharacters = CharacterSet.controlCharacters.union(.newlines)
        if fileName.rangeOfCharacter(from: controlCharacters) != nil {
            throw DataStoreError.invalidFileName(reason: "File name contains control characters")
        }
    }

    /// Validates against reserved Windows names
    private static func validateReservedNames(_ fileName: String) throws {
        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4",
                             "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2",
                             "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        let upperFileName = fileName.uppercased()
        for reservedName in reservedNames {
            let isReservedName = upperFileName == reservedName ||
                                upperFileName.hasPrefix(reservedName + ".")
            if isReservedName {
                throw DataStoreError.invalidFileName(reason: "File name is reserved")
            }
        }
    }

    /// Validates that the directory exists and has appropriate permissions
    private func validateDirectoryPermissions() throws {
        var isDirectory: ObjCBool = false
        let directoryExists = fileManager.fileExists(atPath: baseDirectory.path, isDirectory: &isDirectory)

        // Check if directory exists
        if !directoryExists {
            throw DataStoreError.insufficientPermissions(path: baseDirectory.path)
        }

        // Check if it's actually a directory
        if !isDirectory.boolValue {
            throw DataStoreError.insufficientPermissions(path: baseDirectory.path)
        }

        // Check write permissions
        if !fileManager.isWritableFile(atPath: baseDirectory.path) {
            throw DataStoreError.insufficientPermissions(path: baseDirectory.path)
        }
    }
}
