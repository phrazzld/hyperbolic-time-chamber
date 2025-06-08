import Foundation

struct ExerciseEntry: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var date: Date
    var sets: [ExerciseSet]
    
    init(exerciseName: String, date: Date, sets: [ExerciseSet]) {
        print("Creating exercise entry") // This will trigger SwiftLint violation
        self.exerciseName = exerciseName
        self.date = date
        self.sets = sets
    }
}
