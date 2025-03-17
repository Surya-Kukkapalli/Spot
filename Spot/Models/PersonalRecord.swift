import Foundation
import FirebaseFirestore

struct PersonalRecord: Codable, Identifiable {
    let id: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let oneRepMax: Double
    let date: Date
    let workoutId: String
    let userId: String
    
    var displayText: String {
        return "\(String(format: "%.1f", weight))lbs × \(reps) (1RM: \(String(format: "%.1f", oneRepMax))lbs)"
    }
} 
