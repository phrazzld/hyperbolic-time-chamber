import XCTest

/// UI tests for generating App Store screenshots using Fastlane snapshot
/// These tests drive the app through key user scenarios and capture screenshots
/// at optimal moments for App Store presentation
final class ScreenshotTests: XCTestCase {

    /// Mock snapshot function for when SnapshotHelper is not available
    private func snapshot(_ name: String) {
        // When running without Fastlane, this is a no-op
        // The SnapshotHelper.swift file provides the real implementation
    }

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Launch app with screenshot configuration
        app = XCUIApplication()

        // Configure app for screenshot mode if running under Fastlane
        if ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "1" {
            app.launchArguments += ["-FASTLANE_SNAPSHOT", "1"]
            app.launchArguments += ["-DEMO_MODE", "1"]
            app.launchArguments += ["-UI_TESTING", "1"]
            app.launchArguments += ["-DISABLE_ANIMATIONS", "1"]
        }

        app.launch()

        // Wait for app to fully load
        let tabView = app.tabBars.firstMatch
        XCTAssertTrue(tabView.waitForExistence(timeout: 5.0), "App should launch successfully")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Scenarios

    func testScreenshot01_EmptyState() throws {
        // Screenshot 1: Empty state - clean first impression
        // Shows the app's initial state when no workouts are recorded

        // Ensure we're on the main tab (Workouts)
        let workoutsTab = app.tabBars.buttons["Workouts"]
        if workoutsTab.exists {
            workoutsTab.tap()
        }

        // Wait for content to load
        Thread.sleep(forTimeInterval: 1.0)

        // Take screenshot of empty state
        snapshot("01-EmptyState")
    }

    func testScreenshot02_AddWorkoutForm() throws {
        // Screenshot 2: Add workout form - demonstrates ease of entry
        // Shows the intuitive workout entry interface

        // Navigate to add workout
        let addButton = app.buttons["Add Workout"]
        if !addButton.exists {
            // Try alternative selectors
            let plusButton = app.buttons["+"]
            if plusButton.exists {
                plusButton.tap()
            } else {
                // Fallback: tap toolbar add button
                let toolbarAddButton = app.navigationBars.buttons["Add"]
                XCTAssertTrue(toolbarAddButton.waitForExistence(timeout: 3.0))
                toolbarAddButton.tap()
            }
        } else {
            addButton.tap()
        }

        // Wait for add workout sheet to appear
        let addWorkoutSheet = app.sheets.firstMatch
        if !addWorkoutSheet.waitForExistence(timeout: 3.0) {
            // Try navigation view instead of sheet
            let exerciseNameField = app.textFields["Exercise Name"]
            XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 3.0), "Add workout form should appear")
        }

        // Fill in sample data for screenshot
        let exerciseNameField = app.textFields["Exercise Name"]
        if exerciseNameField.exists {
            exerciseNameField.tap()
            exerciseNameField.typeText("Bench Press")
        }

        // Add a set with sample data
        let repsField = app.textFields["Reps"]
        if repsField.exists {
            repsField.tap()
            repsField.typeText("10")
        }

        let weightField = app.textFields["Weight"]
        if weightField.exists {
            weightField.tap()
            weightField.typeText("135")
        }

        let notesField = app.textFields["Notes"]
        if notesField.exists {
            notesField.tap()
            notesField.typeText("First working set")
        }

        // Wait for UI to settle
        Thread.sleep(forTimeInterval: 1.0)

        // Take screenshot of add workout form
        snapshot("02-AddWorkoutForm")
    }

    func testScreenshot03_WorkoutInProgress() throws {
        // Screenshot 3: Workout in progress - shows multiple sets
        // Demonstrates the app during an active workout session

        // Add sample workout data first
        addSampleWorkout()

        // Navigate back to add more sets to show "in progress" state
        let addButton = app.buttons["Add Workout"]
        if !addButton.exists {
            let plusButton = app.buttons["+"]
            if plusButton.exists {
                plusButton.tap()
            }
        } else {
            addButton.tap()
        }

        // Wait for form
        let exerciseNameField = app.textFields["Exercise Name"]
        if exerciseNameField.waitForExistence(timeout: 3.0) {
            exerciseNameField.tap()
            exerciseNameField.typeText("Squats")

            // Add multiple sets to show progression
            addSetToForm(reps: "12", weight: "115", notes: "Warmup")
            addSetToForm(reps: "10", weight: "155", notes: "Working set 1")
            addSetToForm(reps: "8", weight: "175", notes: "Working set 2")
        }

        Thread.sleep(forTimeInterval: 1.0)
        snapshot("03-WorkoutInProgress")
    }

    func testScreenshot04_WorkoutHistory() throws {
        // Screenshot 4: Workout history - shows progress over time
        // Demonstrates the app's tracking and history capabilities

        // Add multiple sample workouts first
        addSampleWorkout()
        addSampleWorkout(exerciseName: "Deadlifts", weight: "185")
        addSampleWorkout(exerciseName: "Pull-ups", weight: nil, reps: "8")

        // Navigate to history tab
        let historyTab = app.tabBars.buttons["History"]
        if historyTab.exists {
            historyTab.tap()
        } else {
            // Try alternative tab names
            let historyAlternate = app.tabBars.buttons["Past Workouts"]
            if historyAlternate.exists {
                historyAlternate.tap()
            }
        }

        // Wait for history to load
        Thread.sleep(forTimeInterval: 1.5)

        // Take screenshot of workout history
        snapshot("04-WorkoutHistory")
    }

    func testScreenshot05_ExportFeature() throws {
        // Screenshot 5: Export functionality - shows data portability
        // Demonstrates the app's data export capabilities

        // Ensure we have data to export
        addSampleWorkout()

        // Navigate to history tab where export is available
        let historyTab = app.tabBars.buttons["History"]
        if historyTab.exists {
            historyTab.tap()
        }

        // Look for export button (might be in toolbar or as a dedicated button)
        let exportButton = app.buttons["Export"]
        if exportButton.exists {
            exportButton.tap()
        } else {
            // Try share button
            let shareButton = app.buttons["Share"]
            if shareButton.exists {
                shareButton.tap()
            } else {
                // Try navigation bar export
                let navExportButton = app.navigationBars.buttons["Export"]
                if navExportButton.exists {
                    navExportButton.tap()
                }
            }
        }

        // Wait for share sheet to appear
        let shareSheet = app.sheets.firstMatch
        if shareSheet.waitForExistence(timeout: 3.0) {
            Thread.sleep(forTimeInterval: 1.0)
            snapshot("05-ExportFeature")
        } else {
            // Fallback: screenshot the history view with export capability
            snapshot("05-ExportFeature")
        }
    }

    // MARK: - Helper Methods

    private func addSampleWorkout(exerciseName: String = "Bench Press", weight: String? = "135", reps: String = "10") {
        // Helper to add sample workout data for screenshots

        let addButton = app.buttons["Add Workout"]
        if !addButton.exists {
            let plusButton = app.buttons["+"]
            if plusButton.exists {
                plusButton.tap()
            }
        } else {
            addButton.tap()
        }

        // Fill form
        let exerciseField = app.textFields["Exercise Name"]
        if exerciseField.waitForExistence(timeout: 3.0) {
            exerciseField.tap()
            exerciseField.typeText(exerciseName)

            addSetToForm(reps: reps, weight: weight, notes: "Sample set")

            // Save the workout
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            } else {
                // Try "Done" button
                let doneButton = app.buttons["Done"]
                if doneButton.exists {
                    doneButton.tap()
                }
            }
        }

        // Wait for save to complete
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func addSetToForm(reps: String, weight: String?, notes: String?) {
        // Helper to add a set to the current workout form

        let repsField = app.textFields["Reps"]
        if repsField.exists {
            repsField.tap()
            repsField.typeText(reps)
        }

        if let weight = weight {
            let weightField = app.textFields["Weight"]
            if weightField.exists {
                weightField.tap()
                weightField.typeText(weight)
            }
        }

        if let notes = notes {
            let notesField = app.textFields["Notes"]
            if notesField.exists {
                notesField.tap()
                notesField.typeText(notes)
            }
        }

        // Add the set
        let addSetButton = app.buttons["Add Set"]
        if addSetButton.exists {
            addSetButton.tap()
        }
    }
}
