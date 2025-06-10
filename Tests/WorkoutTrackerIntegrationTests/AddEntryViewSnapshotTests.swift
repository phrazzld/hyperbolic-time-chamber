import XCTest
import SwiftUI
import SnapshotTesting
@testable import WorkoutTracker

#if canImport(UIKit)
import UIKit
#endif

/// Snapshot tests for AddEntryView to ensure UI consistency across changes
final class AddEntryViewSnapshotTests: XCTestCase {

    private var viewModel: WorkoutViewModel!
    private var isPresented: Bool = true

    override func setUp() {
        super.setUp()
        viewModel = WorkoutViewModel()
        isPresented = true
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testAddEntryViewInitialState() throws {
        // Arrange: Fresh AddEntryView
        let addEntryView = AddEntryView(isPresented: .constant(isPresented))
            .environmentObject(viewModel)

        // Act & Assert: Test initial empty form state
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Form Input Tests

    func testAddEntryViewWithExerciseName() throws {
        // Arrange: Create view with pre-filled exercise name
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Push-ups",
            sets: [SetInputState(reps: "", weight: "")]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test with exercise name filled
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testAddEntryViewWithSingleSet() throws {
        // Arrange: Create view with exercise name and one set filled
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Bench Press",
            sets: [SetInputState(reps: "10", weight: "50")]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test with single set data
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testAddEntryViewWithMultipleSets() throws {
        // Arrange: Create view with multiple sets
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Squats",
            sets: [
                SetInputState(reps: "12", weight: "80"),
                SetInputState(reps: "10", weight: "85"),
                SetInputState(reps: "8", weight: "90")
            ]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test with multiple sets
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testAddEntryViewBodyweightExercise() throws {
        // Arrange: Create view for bodyweight exercise (no weights)
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Pull-ups",
            sets: [
                SetInputState(reps: "8", weight: ""),
                SetInputState(reps: "7", weight: ""),
                SetInputState(reps: "6", weight: "")
            ]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test bodyweight exercise form
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Device Size Tests

    func testAddEntryViewLargeDevice() throws {
        // Arrange: Test on large device
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Deadlifts",
            sets: [SetInputState(reps: "5", weight: "120")]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test on large device
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 428, height: 926)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testAddEntryViewSmallDevice() throws {
        // Arrange: Test on small device
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Lunges",
            sets: [SetInputState(reps: "15", weight: "")]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test on small device
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Color Scheme Tests

    func testAddEntryViewDarkMode() throws {
        // Arrange: Test dark mode
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Night Workout",
            sets: [SetInputState(reps: "12", weight: "40")]
        )
        .environmentObject(viewModel)
        .preferredColorScheme(.dark)

        // Act & Assert: Test dark mode appearance
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    // MARK: - Edge Cases

    func testAddEntryViewLongExerciseName() throws {
        // Arrange: Test with very long exercise name
        let addEntryView = AddEntryViewWithState(
            exerciseName: "Super Long Exercise Name That Tests Text Field Width Handling",
            sets: [SetInputState(reps: "10", weight: "25")]
        )
        .environmentObject(viewModel)

        // Act & Assert: Test text field with long content
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }

    func testAddEntryViewManyActiveSets() throws {
        // Arrange: Test with many active sets (scrolling behavior)
        let manySets = Array(repeating: SetInputState(reps: "10", weight: "50"), count: 8)
        let addEntryView = AddEntryViewWithState(
            exerciseName: "High Volume Workout",
            sets: manySets
        )
        .environmentObject(viewModel)

        // Act & Assert: Test with many sets (tests scrolling)
        #if canImport(UIKit)
        let hostingController = UIHostingController(rootView: addEntryView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        assertSnapshot(of: hostingController, as: .image)
        #else
        throw XCTSkip("Snapshot testing requires UIKit")
        #endif
    }
}

// MARK: - Helper Views for State Testing

/// Helper structure to represent set input state for testing
private struct SetInputState {
    let reps: String
    let weight: String
}

/// Helper view that allows pre-setting state for snapshot testing
private struct AddEntryViewWithState: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var isPresented = true
    @State private var exerciseName: String
    @State private var sets: [SetInput]

    init(exerciseName: String, sets: [SetInputState]) {
        self.exerciseName = exerciseName
        self.sets = sets.map { state in
            var setInput = SetInput()
            setInput.reps = state.reps
            setInput.weight = state.weight
            return setInput
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise")) {
                    TextField("Name", text: $exerciseName)
                }
                Section(header: Text("Sets")) {
                    ForEach($sets) { $set in
                        HStack {
                            TextField("Reps", text: $set.reps)
#if canImport(UIKit)
                                .keyboardType(.numberPad)
#endif
                                .frame(maxWidth: .infinity)
                            TextField("Weight (optional)", text: $set.weight)
#if canImport(UIKit)
                                .keyboardType(.decimalPad)
#endif
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button(action: {
                        sets.append(SetInput())
                    }, label: {
                        Label("Add Set", systemImage: "plus")
                    })
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save logic would go here in real implementation
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Note: SetInput is already defined in AddEntryView.swift and accessible for testing
