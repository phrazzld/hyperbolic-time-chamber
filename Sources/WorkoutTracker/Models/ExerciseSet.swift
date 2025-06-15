import Foundation

/// Represents a single set within an exercise, containing repetitions, optional weight, and notes.
///
/// A set is the fundamental unit of workout tracking, representing one group of repetitions
/// of an exercise. Sets can optionally include weight (for weighted exercises) and notes
/// for additional context like form cues or difficulty ratings.
///
/// Example usage:
/// ```swift
/// let bodyweightSet = ExerciseSet(reps: 15, weight: nil, notes: "Good form")
/// let weightedSet = ExerciseSet(reps: 8, weight: 185.0, notes: "Felt heavy")
/// ```
public struct ExerciseSet: Identifiable, Codable {
    /// Unique identifier for this set instance
    public var id = UUID()

    /// Number of repetitions performed in this set
    ///
    /// Represents the count of exercise repetitions completed, such as 10 push-ups
    /// or 5 pull-ups. Always a positive integer.
    public var reps: Int

    /// Optional weight used for this set, measured in pounds
    ///
    /// For bodyweight exercises, this value is `nil`. For weighted exercises,
    /// this represents the total weight used (including the weight of bars,
    /// dumbbells, or added resistance).
    public var weight: Double?

    /// Optional notes about this specific set
    ///
    /// Used to record additional context such as:
    /// - Form observations ("good form", "struggled on last rep")
    /// - Difficulty ratings ("felt easy", "very challenging") 
    /// - Equipment notes ("used resistance band", "tempo work")
    /// - Personal reminders for next workout
    public var notes: String?

    /// Public initializer for creating exercise sets
    public init(reps: Int, weight: Double? = nil, notes: String? = nil) {
        self.reps = reps
        self.weight = weight
        self.notes = notes
    }
}
