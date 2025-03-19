import Foundation
import FirebaseFirestore

struct WorkoutProgram: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    var workoutTemplates: [WorkoutTemplate]
    let createdAt: Date
    let updatedAt: Date
    var likes: Int
    var usageCount: Int
    var isPublic: Bool
    
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         description: String? = nil,
         workoutTemplates: [WorkoutTemplate] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         likes: Int = 0,
         usageCount: Int = 0,
         isPublic: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.workoutTemplates = workoutTemplates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.usageCount = usageCount
        self.isPublic = isPublic
    }
    
    var workoutCount: Int {
        return workoutTemplates.count
    }
} 