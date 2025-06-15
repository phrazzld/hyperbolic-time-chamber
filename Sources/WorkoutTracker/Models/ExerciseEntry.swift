import Foundation

/// Represents a single workout exercise entry with multiple sets
public struct ExerciseEntry: Identifiable, Codable {
    public var id = UUID()
    public var exerciseName: String
    public var date: Date
    public var sets: [ExerciseSet]
    public init(exerciseName: String, date: Date, sets: [ExerciseSet]) {
        self.exerciseName = exerciseName
        self.date = date
        self.sets = sets
    }
}
