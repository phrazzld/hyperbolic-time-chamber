import Foundation

/// Represents a single workout exercise entry with multiple sets
struct ExerciseEntry: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var date: Date
    var sets: [ExerciseSet]
    init(exerciseName: String, date: Date, sets: [ExerciseSet]) {
        self.exerciseName = exerciseName
        self.date = date
        self.sets = sets
    }
}
