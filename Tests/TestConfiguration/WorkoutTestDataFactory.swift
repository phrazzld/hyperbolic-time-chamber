import Foundation
import WorkoutTracker

/// Centralized factory for creating consistent test data across all test targets
/// Reduces code duplication and ensures standardized test data patterns
public struct WorkoutTestDataFactory {

    // MARK: - Standard Exercise Names

    /// Common exercise names used across tests for consistency
    public static let commonExerciseNames = [
        "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
        "Overhead Press", "Barbell Rows", "Dips", "Lunges", "Planks",
        "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
        "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
        "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls"
    ]

    /// Subset of exercise names for CI environments
    public static let ciExerciseNames = Array(commonExerciseNames.prefix(5))

    // MARK: - Single Exercise Entry Creation

    /// Creates a basic exercise entry with configurable parameters
    public static func createBasicEntry(
        name: String = "Test Exercise",
        date: Date = Date(),
        setCount: Int = 2,
        baseReps: Int = 10,
        baseWeight: Double = 50.0
    ) -> ExerciseEntry {
        let sets = (0..<setCount).map { index in
            ExerciseSet(
                reps: baseReps - index,
                weight: baseWeight + Double(index * 5)
            )
        }
        return ExerciseEntry(exerciseName: name, date: date, sets: sets)
    }

    /// Creates an exercise entry with progressive weight sets
    public static func createProgressionEntry(
        name: String = "Progressive Exercise",
        date: Date = Date()
    ) -> ExerciseEntry {
        let sets = [
            ExerciseSet(reps: 12, weight: 45.0, notes: "Warmup"),
            ExerciseSet(reps: 10, weight: 135.0, notes: "Working set"),
            ExerciseSet(reps: 8, weight: 155.0, notes: "Heavy set")
        ]
        return ExerciseEntry(exerciseName: name, date: date, sets: sets)
    }

    /// Creates a bodyweight exercise entry (no weights)
    public static func createBodyweightEntry(
        name: String = "Bodyweight Exercise",
        date: Date = Date()
    ) -> ExerciseEntry {
        let sets = [
            ExerciseSet(reps: 20, weight: nil, notes: "Body weight only"),
            ExerciseSet(reps: 15, weight: nil, notes: "Fatigue setting in")
        ]
        return ExerciseEntry(exerciseName: name, date: date, sets: sets)
    }

    /// Creates an entry with special characters for testing edge cases
    public static func createSpecialCharacterEntry(
        date: Date = Date()
    ) -> ExerciseEntry {
        ExerciseEntry(
            exerciseName: "🏋️‍♂️ Special Characters & \"Quotes\" Test",
            date: date,
            sets: [
                ExerciseSet(reps: 0, weight: nil, notes: "Failed attempt"),
                ExerciseSet(reps: 100, weight: 0.0, notes: "Body weight only"),
                ExerciseSet(reps: 1, weight: 200.0, notes: "Max effort 💪")
            ]
        )
    }

    /// Creates an entry with a fixed date for snapshot tests
    public static func createFixedDateEntry(
        name: String = "Snapshot Test Exercise",
        timestamp: TimeInterval = 1672531200
    ) -> ExerciseEntry {
        ExerciseEntry(
            exerciseName: name,
            date: Date(timeIntervalSince1970: timestamp),
            sets: [
                ExerciseSet(reps: 10, weight: 50.0),
                ExerciseSet(reps: 8, weight: 55.0)
            ]
        )
    }

    // MARK: - Multiple Entry Creation

    /// Creates a sample workout history with entries across multiple days
    public static func createSampleWorkoutHistory(
        dayCount: Int = 3,
        baseDate: Date = Date()
    ) -> [ExerciseEntry] {
        (0..<dayCount).map { dayOffset in
            let entryDate = Calendar.current.date(
                byAdding: .day,
                value: -dayOffset * 2,
                to: baseDate
            ) ?? baseDate

            return createBasicEntry(
                name: "Day \(dayOffset + 1) Workout",
                date: entryDate
            )
        }
    }

    /// Creates a week's worth of varied workouts
    public static func createWeeklyWorkouts(
        startDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    ) -> [ExerciseEntry] {
        let workoutDays = [
            ("Monday Upper Body", ["Bench Press", "Pull-ups", "Overhead Press"]),
            ("Wednesday Lower Body", ["Squats", "Deadlifts", "Lunges"]),
            ("Friday Full Body", ["Push-ups", "Squats", "Planks"])
        ]

        return workoutDays.enumerated().compactMap { index, workout in
            let workoutDate = Calendar.current.date(
                byAdding: .day,
                value: index * 2,
                to: startDate
            ) ?? startDate

            let exerciseName = workout.1.randomElement() ?? workout.0
            return createBasicEntry(name: exerciseName, date: workoutDate)
        }
    }

    // MARK: - Large Dataset Generation

    /// Creates a large dataset with configurable size and exercise variety
    public static func createLargeDataset(
        count: Int,
        exerciseNames: [String]? = nil,
        baseDate: Date = Date(),
        timeInterval: TimeInterval = 3600
    ) -> [ExerciseEntry] {
        let names: [String]
        if let exerciseNames = exerciseNames {
            names = exerciseNames
        } else {
            names = TestConfiguration.shared.isCI ? ciExerciseNames : commonExerciseNames
        }

        return (0..<count).map { index in
            let exerciseName = names[index % names.count]
            let entryDate = baseDate.addingTimeInterval(-Double(index) * timeInterval)
            let reps = 10 + index % 5
            let weight = index % 2 == 0 ? nil : Double(50 + index % 100)
            let set = ExerciseSet(reps: reps, weight: weight)

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: entryDate,
                sets: [set]
            )
        }
    }

    /// Creates an optimized dataset for performance tests
    public static func createOptimizedDataset(
        count: Int,
        baseDate: Date = Date(timeIntervalSince1970: 1000000)
    ) -> [ExerciseEntry] {
        let exerciseNames = ["Push-ups", "Squats", "Pull-ups", "Planks", "Burpees"]

        return (0..<count).map { index in
            let exerciseName = exerciseNames[index % exerciseNames.count]
            let entryDate = baseDate.addingTimeInterval(-Double(index) * 3600)
            let weight = index % 2 == 0 ? nil : 50.0
            let set = ExerciseSet(reps: 10, weight: weight)

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: entryDate,
                sets: [set]
            )
        }
    }

    /// Creates a realistic dataset with varied exercise complexity
    public static func createRealisticDataset(
        count: Int,
        baseDate: Date = Date()
    ) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Rows", "Dips", "Lunges", "Planks"
        ]

        return (0..<count).map { index in
            let exerciseName = exerciseNames[index % exerciseNames.count]

            let setCount = Int.random(in: 1...4)
            let sets = (0..<setCount).map { setIndex in
                ExerciseSet(
                    reps: Int.random(in: 5...15),
                    weight: setIndex == 0 ? nil : Double.random(in: 20...150)
                )
            }

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: baseDate.addingTimeInterval(-Double(index) * 3600),
                sets: sets
            )
        }
    }

    /// Creates an extreme dataset for stress testing
    public static func createExtremeDataset(
        count: Int,
        baseDate: Date = Date()
    ) -> [ExerciseEntry] {
        let exerciseNames = [
            "Push-ups", "Pull-ups", "Squats", "Deadlifts", "Bench Press",
            "Overhead Press", "Barbell Rows", "Dips", "Lunges", "Planks",
            "Burpees", "Mountain Climbers", "Jumping Jacks", "Russian Twists",
            "Bicep Curls", "Tricep Extensions", "Shoulder Press", "Lat Pulldowns",
            "Leg Press", "Calf Raises", "Hip Thrusts", "Face Pulls",
            "Arnold Press", "Bulgarian Split Squats", "Romanian Deadlifts",
            "Incline Bench Press", "Decline Bench Press", "Front Squats",
            "Sumo Deadlifts", "Close-Grip Bench Press"
        ]

        return (0..<count).map { index in
            let exerciseName = exerciseNames[index % exerciseNames.count]

            // Generate more complex sets for stress testing
            let setCount = Int.random(in: 1...6)
            let sets = (0..<setCount).map { setIndex in
                ExerciseSet(
                    reps: Int.random(in: 1...25),
                    weight: setIndex == 0 ? nil : Double.random(in: 5...300)
                )
            }

            return ExerciseEntry(
                exerciseName: exerciseName,
                date: baseDate.addingTimeInterval(-Double(index) * Double.random(in: 300...7200)),
                sets: sets
            )
        }
    }

    // MARK: - Configuration-Aware Helpers

    /// Creates a dataset sized appropriately for the current test environment
    public static func createEnvironmentSizedDataset(
        category: DatasetCategory,
        exerciseNames: [String]? = nil
    ) -> [ExerciseEntry] {
        let config = TestConfiguration.shared
        let size = config.datasetSize(for: category)

        switch category {
        case .small, .medium:
            return createOptimizedDataset(count: size)
        case .large:
            return createRealisticDataset(count: size)
        case .extraLarge, .stress:
            return createExtremeDataset(count: size)
        }
    }

    /// Gets exercise names appropriate for the current test environment
    public static func getEnvironmentExerciseNames() -> [String] {
        TestConfiguration.shared.isCI ? ciExerciseNames : commonExerciseNames
    }
}

// MARK: - TestConfiguration Extension

public extension TestConfiguration {
    /// Get appropriate test data factory based on environment
    var testDataFactory: WorkoutTestDataFactory.Type {
        WorkoutTestDataFactory.self
    }

    /// Standard exercise names for consistent testing
    var standardExerciseNames: [String] {
        WorkoutTestDataFactory.getEnvironmentExerciseNames()
    }
}
