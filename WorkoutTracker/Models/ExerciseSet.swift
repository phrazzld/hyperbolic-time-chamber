import Foundation

struct ExerciseSet: Identifiable, Codable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double? = nil
    var notes: String? = nil
}