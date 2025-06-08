import SwiftUI

/// Application entry point
@main
struct WorkoutTrackerApp: App {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
