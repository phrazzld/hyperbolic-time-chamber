import XCTest
import SwiftUI
import SnapshotTesting
@testable import WorkoutTracker

#if canImport(UIKit)
import UIKit
#endif

/// Snapshot tests for HistoryView to ensure UI consistency across changes
final class HistoryViewSnapshotTests: XCTestCase {

    private var viewModel: WorkoutViewModel!

    override func setUp() {
        super.setUp()
        // Use InMemoryDataStore for tests to avoid file system interactions
        let dataStore = InMemoryDataStore()
        viewModel = WorkoutViewModel(dataStore: dataStore)
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Empty State Tests

    func testHistoryViewEmptyState() throws {
        // Arrange: Ensure empty history
        viewModel.entries.removeAll()

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test empty state appearance
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844) // iPhone 13 size
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Single Entry Tests

    func testHistoryViewSingleEntry() throws {
        // Arrange: Add single workout entry
        let singleSet = ExerciseSet(reps: 10, weight: 50.0)
        let entry = ExerciseEntry(
            exerciseName: "Push-ups",
            date: Date(timeIntervalSince1970: 1672531200), // Fixed date for consistent snapshots
            sets: [singleSet]
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test single entry display
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testHistoryViewSingleEntryMultipleSets() throws {
        // Arrange: Add entry with multiple sets
        let sets = [
            ExerciseSet(reps: 10, weight: 50.0),
            ExerciseSet(reps: 8, weight: 55.0),
            ExerciseSet(reps: 6, weight: 60.0)
        ]
        let entry = ExerciseEntry(
            exerciseName: "Bench Press",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: sets
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test multiple sets display
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testHistoryViewSingleEntryBodyweightExercise() throws {
        // Arrange: Add bodyweight exercise (no weight)
        let bodyweightSet = ExerciseSet(reps: 20, weight: nil)
        let entry = ExerciseEntry(
            exerciseName: "Jumping Jacks",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [bodyweightSet]
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test bodyweight exercise display (no weight shown)
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Multiple Entry Tests

    func testHistoryViewMultipleEntries() throws {
        // Arrange: Add multiple workout entries across different dates
        let entries = [
            ExerciseEntry(
                exerciseName: "Squats",
                date: Date(timeIntervalSince1970: 1672531200), // Earlier date
                sets: [ExerciseSet(reps: 12, weight: 80.0)]
            ),
            ExerciseEntry(
                exerciseName: "Deadlifts",
                date: Date(timeIntervalSince1970: 1672617600), // Later date
                sets: [ExerciseSet(reps: 5, weight: 120.0)]
            ),
            ExerciseEntry(
                exerciseName: "Pull-ups",
                date: Date(timeIntervalSince1970: 1672704000), // Latest date
                sets: [ExerciseSet(reps: 8, weight: nil)]
            )
        ]

        for entry in entries {
            viewModel.addEntry(entry)
        }

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test multiple entries display (should be sorted by date, newest first)
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Device Size Tests

    func testHistoryViewLargeDevice() throws {
        // Arrange: Add sample data for large device test
        let entry = ExerciseEntry(
            exerciseName: "Olympic Squats",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [
                ExerciseSet(reps: 5, weight: 100.0),
                ExerciseSet(reps: 5, weight: 105.0)
            ]
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test on larger device
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 428, height: 926)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testHistoryViewSmallDevice() throws {
        // Arrange: Add sample data for small device test
        let entry = ExerciseEntry(
            exerciseName: "Running",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [ExerciseSet(reps: 30, weight: nil)] // Minutes
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test on smaller device
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Color Scheme Tests

    func testHistoryViewDarkMode() throws {
        // Arrange: Add sample data for dark mode test
        let entry = ExerciseEntry(
            exerciseName: "Evening Workout",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [ExerciseSet(reps: 15, weight: 45.0)]
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)
            .preferredColorScheme(.dark)

        // Act & Assert: Test dark mode appearance
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Long Exercise Names Test

    func testHistoryViewLongExerciseName() throws {
        // Arrange: Test with very long exercise name
        let entry = ExerciseEntry(
            exerciseName: "Extremely Long Exercise Name That Should Wrap Properly In The Interface",
            date: Date(timeIntervalSince1970: 1672531200),
            sets: [ExerciseSet(reps: 10, weight: 25.0)]
        )
        viewModel.addEntry(entry)

        let historyView = HistoryView()
            .environmentObject(viewModel)

        // Act & Assert: Test text wrapping and layout with long names
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: historyView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        // macOS testing would use NSHostingController
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }
}
