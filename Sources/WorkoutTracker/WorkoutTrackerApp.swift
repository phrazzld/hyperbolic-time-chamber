import SwiftUI

/// Application entry point
@main
struct WorkoutTrackerApp: App {
    @StateObject private var viewModel: WorkoutViewModel

    init() {
        // Use the dependency factory to create view model with proper configuration
        let workoutViewModel = DependencyFactory.createViewModel()
        _viewModel = StateObject(wrappedValue: workoutViewModel)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Populate with demo data for screenshots
                    DemoDataService.populateWithDemoDataIfNeeded(viewModel)
                }
        }
    }
}
