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
    
    init(id: String, name: String, bodyPart: String, equipment: String, gifUrl: String, target: String, secondaryMuscles: [String], instructions: [String]) {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
        self.equipment = equipment
        self.gifUrl = gifUrl
        self.target = target
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
    }
    
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
struct Exercise: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var sets: [ExerciseSet]
    let equipment: Equipment
    let gifUrl: String
    let target: String  // Primary target muscle
    let secondaryMuscles: [String]  // Secondary muscles worked
    var notes: String?
    
    init(id: String, name: String, sets: [ExerciseSet] = [], equipment: Equipment, gifUrl: String = "", target: String = "", secondaryMuscles: [String] = [], notes: String? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.equipment = equipment
        self.gifUrl = gifUrl
        self.target = target
        self.secondaryMuscles = secondaryMuscles
        self.notes = notes
    }
    
    init(from template: ExerciseTemplate) {
        self.id = UUID().uuidString
        self.name = template.name
        self.sets = []
        self.equipment = .custom(template.equipment)
        self.gifUrl = template.gifUrl
        self.target = template.target
        self.secondaryMuscles = template.secondaryMuscles
    }
    
    enum CodingKeys: CodingKey {
        case id, name, sets, equipment, gifUrl, target, secondaryMuscles, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sets = try container.decode([ExerciseSet].self, forKey: .sets)
        equipment = try container.decode(Equipment.self, forKey: .equipment)
        gifUrl = try container.decode(String.self, forKey: .gifUrl)
        target = try container.decode(String.self, forKey: .target)
        secondaryMuscles = try container.decode([String].self, forKey: .secondaryMuscles)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sets, forKey: .sets)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(gifUrl, forKey: .gifUrl)
        try container.encode(target, forKey: .target)
        try container.encode(secondaryMuscles, forKey: .secondaryMuscles)
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.sets == rhs.sets &&
               lhs.equipment == rhs.equipment &&
               lhs.gifUrl == rhs.gifUrl &&
               lhs.target == rhs.target &&
               lhs.secondaryMuscles == rhs.secondaryMuscles &&
               lhs.notes == rhs.notes
    }
    
    func toTemplate() -> ExerciseTemplate {
        return ExerciseTemplate(
            id: id,
            name: name,
            bodyPart: target, // Using target as bodyPart since they're related
            equipment: equipment.description,
            gifUrl: gifUrl,
            target: target,
            secondaryMuscles: secondaryMuscles,
            instructions: [] // Instructions are typically loaded from the API
        )
    }
}

// Exercise Set model
struct ExerciseSet: Identifiable, Codable, Equatable {
    var id: String
    var weight: Double = 0
    var reps: Int = 0
    var type: SetType = .normal
    var isCompleted: Bool = false
    var restInterval: TimeInterval = 90 // Default 90 seconds rest
    var isPR: Bool = false
    
    enum SetType: String, Codable {
        case normal
        case warmup
        case failure
        case dropset
        case superset
    }
    
    var volume: Double {
        return weight * Double(reps)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case weight
        case reps
        case type
        case isCompleted
        case restInterval
        case isPR
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)
        type = try container.decode(SetType.self, forKey: .type)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        restInterval = try container.decode(TimeInterval.self, forKey: .restInterval)
        isPR = try container.decodeIfPresent(Bool.self, forKey: .isPR) ?? false
    }
    
    init(id: String) {
        self.id = id
    }
    
    static func == (lhs: ExerciseSet, rhs: ExerciseSet) -> Bool {
        return lhs.id == rhs.id &&
               lhs.weight == rhs.weight &&
               lhs.reps == rhs.reps &&
               lhs.type == rhs.type &&
               lhs.isCompleted == rhs.isCompleted &&
               lhs.restInterval == rhs.restInterval &&
               lhs.isPR == rhs.isPR
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

    init() {
        self = .bodyweight
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
