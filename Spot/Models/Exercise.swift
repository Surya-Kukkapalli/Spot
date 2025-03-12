import Foundation

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