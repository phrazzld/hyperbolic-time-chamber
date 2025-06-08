import Foundation

struct ExerciseSet: Identifiable, Codable {
    var id = UUID()
    var reps: Int
    var weight: Double?
    var notes: String?
}
