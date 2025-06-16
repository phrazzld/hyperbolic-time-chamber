import XCTest
import Foundation
@testable import WorkoutTracker

/// Comprehensive security tests for FileDataStore to prevent vulnerabilities
final class FileDataStoreSecurityTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecurityTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Path Traversal Prevention Tests

    func testPathTraversalAttackPrevention() {
        // Test various path traversal attack patterns
        let maliciousFileNames = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\SAM",
            "./../sensitive/file.txt",
            "normal/../../../malicious.txt",
            "/etc/passwd",
            "\\windows\\system32\\config\\SAM",
            "..\\malicious.txt",
            "../malicious.txt"
        ]

        for maliciousFileName in maliciousFileNames {
            XCTAssertThrowsError(
                try FileDataStore(baseDirectory: tempDirectory, fileName: maliciousFileName),
                "Should throw error for path traversal attempt: \(maliciousFileName)"
            ) { error in
                guard let dataStoreError = error as? DataStoreError else {
                    XCTFail("Should throw DataStoreError, got: \(error)")
                    return
                }

                switch dataStoreError {
                case .pathTraversalAttempt(let fileName):
                    XCTAssertEqual(fileName, maliciousFileName)
                case .invalidFileName:
                    // Also acceptable for some patterns
                    break
                default:
                    XCTFail("Expected pathTraversalAttempt or invalidFileName error, got: \(dataStoreError)")
                }
            }
        }
    }

    // MARK: - File Name Validation Tests

    func testInvalidFileNameRejection() {
        let invalidFileNames = [
            "",                    // Empty string
            " ",                   // Whitespace only
            "\t",                  // Tab character
            "\n",                  // Newline character
            "file<name>.json",     // Contains illegal character <
            "file>name.json",      // Contains illegal character >
            "file:name.json",      // Contains illegal character : (on Windows)
            "file\"name.json",     // Contains illegal character "
            "file|name.json",      // Contains illegal character |
            "file?name.json",      // Contains illegal character ?
            "file*name.json",      // Contains illegal character *
            "CON",                 // Reserved Windows name
            "PRN",                 // Reserved Windows name
            "AUX",                 // Reserved Windows name
            "NUL",                 // Reserved Windows name
            "COM1",                // Reserved Windows name
            "LPT1",                // Reserved Windows name
            String(repeating: "a", count: 256) // Too long filename
        ]

        for invalidFileName in invalidFileNames {
            XCTAssertThrowsError(
                try FileDataStore(baseDirectory: tempDirectory, fileName: invalidFileName),
                "Should throw error for invalid file name: '\(invalidFileName)'"
            ) { error in
                guard let dataStoreError = error as? DataStoreError else {
                    XCTFail("Should throw DataStoreError, got: \(error)")
                    return
                }

                if case .invalidFileName = dataStoreError {
                    // Expected
                } else {
                    XCTFail("Expected invalidFileName error, got: \(dataStoreError)")
                }
            }
        }
    }

    func testValidFileNameAcceptance() {
        let validFileNames = [
            "workout_entries.json",
            "data.json",
            "backup-2023-12-01.json",
            "user_data_v2.json",
            "exercise.data",
            "WorkoutData.json",
            "123.json",
            "a.json",
            "file.with.dots.json"
        ]

        for validFileName in validFileNames {
            XCTAssertNoThrow(
                try FileDataStore(baseDirectory: tempDirectory, fileName: validFileName),
                "Should accept valid file name: \(validFileName)"
            )
        }
    }

    // MARK: - Permission Validation Tests

    func testReadOnlyDirectoryHandling() {
        // Create a read-only directory
        let readOnlyDir = tempDirectory.appendingPathComponent("readonly")
        try? FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)

        // Make directory read-only (remove write permissions)
        guard var attributes = try? FileManager.default.attributesOfItem(atPath: readOnlyDir.path) else {
            XCTFail("Could not get directory attributes")
            return
        }
        attributes[.posixPermissions] = 0o444 // Read-only permissions
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: readOnlyDir.path)

        defer {
            // Restore write permissions for cleanup
            attributes[.posixPermissions] = 0o755
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: readOnlyDir.path)
        }

        // Test that FileDataStore detects insufficient permissions
        XCTAssertThrowsError(
            try FileDataStore(baseDirectory: readOnlyDir, fileName: "test.json"),
            "Should throw error for insufficient permissions"
        ) { error in
            guard let dataStoreError = error as? DataStoreError else {
                XCTFail("Should throw DataStoreError, got: \(error)")
                return
            }

            if case .insufficientPermissions = dataStoreError {
                // Expected
            } else {
                XCTFail("Expected insufficientPermissions error, got: \(dataStoreError)")
            }
        }
    }

    func testNonExistentDirectoryHandling() {
        let nonExistentDir = tempDirectory.appendingPathComponent("does_not_exist")

        // Test that FileDataStore handles non-existent directories appropriately
        XCTAssertThrowsError(
            try FileDataStore(baseDirectory: nonExistentDir, fileName: "test.json"),
            "Should throw error for non-existent directory"
        ) { error in
            guard let dataStoreError = error as? DataStoreError else {
                XCTFail("Should throw DataStoreError, got: \(error)")
                return
            }

            if case .insufficientPermissions = dataStoreError {
                // Expected - can't write to non-existent directory
            } else {
                XCTFail("Expected insufficientPermissions error, got: \(dataStoreError)")
            }
        }
    }

    // MARK: - Path Boundary Validation Tests

    func testFileURLStaysWithinBoundaries() throws {
        let dataStore = try FileDataStore(baseDirectory: tempDirectory, fileName: "safe.json")

        // Use reflection/inspection to verify the constructed fileURL is within boundaries
        // This tests the internal fileURL property to ensure it's constructed safely
        _ = Mirror(reflecting: dataStore)

        // We can't access private properties directly, but we can test the behavior
        // by attempting operations and ensuring they stay within the temp directory

        let testEntries: [ExerciseEntry] = []
        XCTAssertNoThrow(try dataStore.save(entries: testEntries))

        // Verify the file was created in the expected location
        let expectedFileURL = tempDirectory.appendingPathComponent("safe.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedFileURL.path),
            "File should be created in the specified directory"
        )

        // Verify the file path is actually within our temp directory
        let resolvedPath = expectedFileURL.resolvingSymlinksInPath().path
        let tempPath = tempDirectory.resolvingSymlinksInPath().path
        XCTAssertTrue(
            resolvedPath.hasPrefix(tempPath),
            "File path should be within the specified directory boundary"
        )
    }

    // MARK: - Security Error Message Tests

    func testSecurityErrorMessagesDoNotLeakInformation() {
        // Test that security error messages don't expose sensitive system information

        do {
            _ = try FileDataStore(baseDirectory: tempDirectory, fileName: "../../../etc/passwd")
            XCTFail("Should have thrown an error")
        } catch let error as DataStoreError {
            let errorMessage = error.localizedDescription

            // Verify error message doesn't expose sensitive paths
            XCTAssertFalse(errorMessage.contains("/etc/passwd"), "Error message should not expose sensitive paths")
            XCTAssertFalse(errorMessage.contains("system32"), "Error message should not expose system paths")

            // Verify it's appropriately generic but informative
            XCTAssertTrue(
                errorMessage.contains("Path traversal") || errorMessage.contains("Invalid file"),
                "Error message should indicate the security issue type"
            )
        } catch {
            XCTFail("Should throw DataStoreError, got: \(error)")
        }
    }
}
