import Foundation
import FirebaseFirestore

struct WorkoutProgram: Identifiable, Codable {
    var id: String
    var userId: String
    var name: String
    var description: String?
    var workoutTemplates: [WorkoutTemplate]
    var createdAt: Date
    var updatedAt: Date
    var likes: Int
    var usageCount: Int
    var isPublic: Bool
    
    var workoutCount: Int {
        workoutTemplates.count
    }
    
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
} 