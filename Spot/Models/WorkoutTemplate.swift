import Foundation
import FirebaseFirestore

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let exercises: [Exercise]
    let createdAt: Date
    let updatedAt: Date
    var likes: Int
    var usageCount: Int
    var isPublic: Bool
    
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         description: String? = nil,
         exercises: [Exercise] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         likes: Int = 0,
         usageCount: Int = 0,
         isPublic: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.usageCount = usageCount
        self.isPublic = isPublic
    }
    
    static func fromWorkout(_ workout: Workout, description: String? = nil, isPublic: Bool = false) -> WorkoutTemplate {
        return WorkoutTemplate(
            userId: workout.userId,
            name: workout.name,
            description: description,
            exercises: workout.exercises,
            isPublic: isPublic
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WorkoutTemplate, rhs: WorkoutTemplate) -> Bool {
        return lhs.id == rhs.id
    }
} 