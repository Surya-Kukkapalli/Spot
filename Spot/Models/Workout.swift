import Foundation
import FirebaseFirestore

struct Workout: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    var name: String
    var exercises: [Exercise]
    var duration: TimeInterval
    var notes: String?
    var createdAt: Date
    var isTemplate: Bool
    var templateAuthorId: String?
    var templatePrice: Double?
    
    // For social features
    var likes: Int
    var comments: Int
    var shares: Int
}

struct Exercise: Identifiable, Codable {
    var id: String
    var name: String
    var sets: [ExerciseSet]
    var notes: String?
    var equipment: Equipment
    var previousPersonalRecord: Double?
}

struct ExerciseSet: Identifiable, Codable {
    var id: String
    var weight: Double
    var reps: Int
    var type: SetType
    var isCompleted: Bool
    var restInterval: TimeInterval
    
    enum SetType: String, Codable {
        case normal
        case warmup
        case failure
        case dropset
        case superset
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case smith
    case other
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
} 