import Foundation

/// Service for providing demo data during screenshot generation and UI testing
/// This ensures consistent, attractive sample data for App Store screenshots
struct DemoDataService {

    /// Checks if the app is running in demo mode for screenshots
    static var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-DEMO_MODE") ||
               ProcessInfo.processInfo.environment["DEMO_MODE"] == "1"
    }

    /// Checks if the app is running under Fastlane snapshot
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") ||
               ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "1"
    }

    /// Checks if UI testing mode is enabled
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UI_TESTING") ||
               ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
    }

    /// Generates demo workout entries for screenshots
    /// These are designed to showcase the app's capabilities and look professional
    static func generateDemoWorkouts() -> [ExerciseEntry] {
        let calendar = Calendar.current
        let now = Date()

        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now),
              let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return []
        }

        return [
            generateChestWorkouts(date: oneWeekAgo),
            generateLegWorkouts(date: fiveDaysAgo),
            generateBackWorkouts(date: threeDaysAgo),
            generateShoulderWorkouts(date: yesterday),
            generateCurrentWorkout(date: now)
        ].flatMap { $0 }
    }

    /// Generates chest workout entries for demo data
    private static func generateChestWorkouts(date: Date) -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Bench Press",
                date: date,
                sets: [
                    ExerciseSet(reps: 12, weight: 135.0, notes: "Warmup"),
                    ExerciseSet(reps: 10, weight: 155.0, notes: "Working set"),
                    ExerciseSet(reps: 8, weight: 175.0, notes: "Heavy set"),
                    ExerciseSet(reps: 6, weight: 185.0, notes: "PR attempt!")
                ]
            ),
            ExerciseEntry(
                exerciseName: "Incline Dumbbell Press",
                date: date,
                sets: [
                    ExerciseSet(reps: 12, weight: 60.0, notes: "Each arm"),
                    ExerciseSet(reps: 10, weight: 65.0, notes: "Good form"),
                    ExerciseSet(reps: 8, weight: 70.0, notes: "Challenging")
                ]
            )
        ]
    }

    /// Generates leg workout entries for demo data
    private static func generateLegWorkouts(date: Date) -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Squats",
                date: date,
                sets: [
                    ExerciseSet(reps: 15, weight: 95.0, notes: "Warmup with bar"),
                    ExerciseSet(reps: 12, weight: 135.0, notes: "Building up"),
                    ExerciseSet(reps: 10, weight: 185.0, notes: "Working weight"),
                    ExerciseSet(reps: 8, weight: 205.0, notes: "Felt strong"),
                    ExerciseSet(reps: 20, weight: 135.0, notes: "Burnout set")
                ]
            ),
            ExerciseEntry(
                exerciseName: "Romanian Deadlifts",
                date: date,
                sets: [
                    ExerciseSet(reps: 12, weight: 115.0, notes: "Focus on form"),
                    ExerciseSet(reps: 10, weight: 135.0, notes: "Good stretch"),
                    ExerciseSet(reps: 8, weight: 155.0, notes: "Controlled tempo")
                ]
            )
        ]
    }

    /// Generates back workout entries for demo data
    private static func generateBackWorkouts(date: Date) -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Pull-ups",
                date: date,
                sets: [
                    ExerciseSet(reps: 8, weight: nil, notes: "Bodyweight"),
                    ExerciseSet(reps: 6, weight: nil, notes: "Clean reps"),
                    ExerciseSet(reps: 5, weight: nil, notes: "Getting tired"),
                    ExerciseSet(reps: 3, weight: nil, notes: "Final push")
                ]
            ),
            ExerciseEntry(
                exerciseName: "Barbell Rows",
                date: date,
                sets: [
                    ExerciseSet(reps: 12, weight: 115.0, notes: "Warmup"),
                    ExerciseSet(reps: 10, weight: 135.0, notes: "Working set"),
                    ExerciseSet(reps: 8, weight: 155.0, notes: "Heavy and controlled")
                ]
            )
        ]
    }

    /// Generates shoulder workout entries for demo data
    private static func generateShoulderWorkouts(date: Date) -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Overhead Press",
                date: date,
                sets: [
                    ExerciseSet(reps: 10, weight: 95.0, notes: "Warmup"),
                    ExerciseSet(reps: 8, weight: 115.0, notes: "Working weight"),
                    ExerciseSet(reps: 6, weight: 125.0, notes: "Heavy set"),
                    ExerciseSet(reps: 10, weight: 95.0, notes: "Drop set")
                ]
            ),
            ExerciseEntry(
                exerciseName: "Lateral Raises",
                date: date,
                sets: [
                    ExerciseSet(reps: 15, weight: 20.0, notes: "Light and controlled"),
                    ExerciseSet(reps: 12, weight: 25.0, notes: "Feel the burn"),
                    ExerciseSet(reps: 10, weight: 30.0, notes: "Challenging weight")
                ]
            )
        ]
    }

    /// Generates current workout in progress for demo data
    private static func generateCurrentWorkout(date: Date) -> [ExerciseEntry] {
        [
            ExerciseEntry(
                exerciseName: "Deadlifts",
                date: date,
                sets: [
                    ExerciseSet(reps: 10, weight: 135.0, notes: "Warmup"),
                    ExerciseSet(reps: 8, weight: 185.0, notes: "Building up"),
                    ExerciseSet(reps: 5, weight: 225.0, notes: "Working weight")
                ]
            )
        ]
    }

    /// Returns a smaller set of demo workouts for specific screenshot scenarios
    static func generateMinimalDemoWorkouts() -> [ExerciseEntry] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        return [
            ExerciseEntry(
                exerciseName: "Bench Press",
                date: yesterday,
                sets: [
                    ExerciseSet(reps: 10, weight: 135.0, notes: "Working set"),
                    ExerciseSet(reps: 8, weight: 155.0, notes: "Heavy set"),
                    ExerciseSet(reps: 6, weight: 165.0, notes: "New PR!")
                ]
            ),

            ExerciseEntry(
                exerciseName: "Squats",
                date: Date(),
                sets: [
                    ExerciseSet(reps: 12, weight: 115.0, notes: "Warmup"),
                    ExerciseSet(reps: 10, weight: 185.0, notes: "Working weight")
                ]
            )
        ]
    }

    /// Populates a WorkoutViewModel with demo data if in demo mode
    static func populateWithDemoDataIfNeeded(_ viewModel: WorkoutViewModel) {
        guard isDemoMode || isScreenshotMode else { return }

        let demoWorkouts = generateDemoWorkouts()
        for workout in demoWorkouts {
            viewModel.addEntry(workout)
        }
    }
}
