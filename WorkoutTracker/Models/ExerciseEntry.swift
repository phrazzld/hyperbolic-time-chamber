import Foundation

struct ExerciseEntry: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var date: Date
    var sets: [ExerciseSet]
}
