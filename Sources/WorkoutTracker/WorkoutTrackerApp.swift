import SwiftUI

/// Application entry point
@main
struct WorkoutTrackerApp: App {
    @StateObject private var viewModel: WorkoutViewModel

    init() {
        // Use the dependency factory to create view model with proper configuration
        let workoutViewModel: WorkoutViewModel
        do {
            workoutViewModel = try DependencyFactory.createViewModel()
        } catch {
            // Fallback to in-memory store if file-based store fails for security reasons
            NSLog("Failed to create file-based view model, falling back to in-memory store: \(error)")
            workoutViewModel = DependencyFactory.createViewModel(dataStore: InMemoryDataStore())
        }
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
