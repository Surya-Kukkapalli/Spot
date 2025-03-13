import Foundation

// ExerciseTemplate for API responses
struct ExerciseTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let bodyPart: String
    let equipment: String
    let gifUrl: String
    let target: String
    let secondaryMuscles: [String]
    let instructions: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, bodyPart, equipment, gifUrl, target, secondaryMuscles, instructions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idValue = try container.decode(String.self, forKey: .id)
        self.id = idValue
        self.name = try container.decode(String.self, forKey: .name)
        self.bodyPart = try container.decode(String.self, forKey: .bodyPart)
        self.equipment = try container.decode(String.self, forKey: .equipment)
        self.gifUrl = try container.decode(String.self, forKey: .gifUrl)
        self.target = try container.decode(String.self, forKey: .target)
        self.secondaryMuscles = try container.decode([String].self, forKey: .secondaryMuscles)
        self.instructions = try container.decode([String].self, forKey: .instructions)
    }
}

// Main Exercise model
struct Exercise: Identifiable, Codable {
    let id: String
    var name: String
    var sets: [ExerciseSet]
    var equipment: Equipment
    var notes: String?
    var restTimerEnabled: Bool
    var gifUrl: String
    
    enum CodingKeys: CodingKey {
        case id, name, sets, equipment, notes, restTimerEnabled, gifUrl
    }
    
    init(from template: ExerciseTemplate) {
        self.id = UUID().uuidString
        self.name = template.name
        self.sets = [ExerciseSet(id: UUID().uuidString)] // Start with one empty set
        self.equipment = .custom(template.equipment)
        self.restTimerEnabled = false
        self.gifUrl = template.gifUrl
        self.notes = nil
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         sets: [ExerciseSet] = [],
         equipment: Equipment,
         notes: String? = nil,
         restTimerEnabled: Bool = false,
         gifUrl: String = "") {
        self.id = id
        self.name = name
        self.sets = sets
        self.equipment = equipment
        self.notes = notes
        self.restTimerEnabled = restTimerEnabled
        self.gifUrl = gifUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sets = try container.decode([ExerciseSet].self, forKey: .sets)
        equipment = try container.decode(Equipment.self, forKey: .equipment)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        restTimerEnabled = try container.decode(Bool.self, forKey: .restTimerEnabled)
        gifUrl = try container.decode(String.self, forKey: .gifUrl)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sets, forKey: .sets)
        try container.encode(equipment, forKey: .equipment)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(restTimerEnabled, forKey: .restTimerEnabled)
        try container.encode(gifUrl, forKey: .gifUrl)
    }
}

// Exercise Set model
struct ExerciseSet: Identifiable, Codable {
    var id: String
    var weight: Double = 0
    var reps: Int = 0
    var type: SetType = .normal
    var isCompleted: Bool = false
    var restInterval: TimeInterval = 90 // Default 90 seconds rest
    
    enum SetType: String, Codable {
        case normal
        case warmup
        case failure
        case dropset
        case superset
    }
}

// Equipment enum
enum Equipment: Codable, Equatable, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
    case custom(String)
    
    static var allCases: [Equipment] {
        [.barbell, .dumbbell, .machine, .bodyweight]
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .barbell: hasher.combine("barbell")
        case .dumbbell: hasher.combine("dumbbell")
        case .machine: hasher.combine("machine")
        case .bodyweight: hasher.combine("bodyweight")
        case .custom(let value): hasher.combine(value)
        }
    }
    
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
