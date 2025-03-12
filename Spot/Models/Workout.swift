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
    let id: String
    var name: String
    var sets: [ExerciseSet]
    var equipment: Equipment
    
    // Add a convenience initializer for creating from template
    init(from template: ExerciseTemplate) {
        self.id = UUID().uuidString
        self.name = template.name
        self.sets = []
        self.equipment = .custom(template.equipment)
    }
    
    // Keep the existing initializer
    init(id: String = UUID().uuidString, name: String, sets: [ExerciseSet], equipment: Equipment) {
        self.id = id
        self.name = name
        self.sets = sets
        self.equipment = equipment
    }
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

enum Equipment: Codable, Equatable, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
    case custom(String)
    
    static var allCases: [Equipment] {
        [.barbell, .dumbbell, .machine, .bodyweight]
    }
    
    // Add hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .barbell: hasher.combine("barbell")
        case .dumbbell: hasher.combine("dumbbell")
        case .machine: hasher.combine("machine")
        case .bodyweight: hasher.combine("bodyweight")
        case .custom(let value): hasher.combine(value)
        }
    }
    
    // Add coding support for the custom case
    private enum CodingKeys: String, CodingKey {
        case type
        case customValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type.lowercased() {
        case "barbell": self = .barbell
        case "dumbbell": self = .dumbbell
        case "machine": self = .machine
        case "bodyweight": self = .bodyweight
        default:
            let customValue = try container.decode(String.self, forKey: .customValue)
            self = .custom(customValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .barbell:
            try container.encode("barbell", forKey: .type)
        case .dumbbell:
            try container.encode("dumbbell", forKey: .type)
        case .machine:
            try container.encode("machine", forKey: .type)
        case .bodyweight:
            try container.encode("bodyweight", forKey: .type)
        case .custom(let value):
            try container.encode("custom", forKey: .type)
            try container.encode(value, forKey: .customValue)
        }
    }
    
    var description: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .bodyweight: return "Bodyweight"
        case .custom(let value): return value.capitalized
        }
    }
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
} 