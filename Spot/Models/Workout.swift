import Foundation
import FirebaseFirestore

struct Workout: Identifiable, Codable {
    var id: String
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
    
    enum CodingKeys: String, CodingKey {
        case id, userId, name, exercises, duration, notes, createdAt, isTemplate, 
             templateAuthorId, templatePrice, likes, comments, shares
    }
    
    init(id: String,
         userId: String,
         name: String,
         exercises: [Exercise] = [],
         duration: TimeInterval = 0,
         notes: String? = nil,
         createdAt: Date = Date(),
         isTemplate: Bool = false,
         templateAuthorId: String? = nil,
         templatePrice: Double? = nil,
         likes: Int = 0,
         comments: Int = 0,
         shares: Int = 0) {
        self.id = id
        self.userId = userId
        self.name = name
        self.exercises = exercises
        self.duration = duration
        self.notes = notes
        self.createdAt = createdAt
        self.isTemplate = isTemplate
        self.templateAuthorId = templateAuthorId
        self.templatePrice = templatePrice
        self.likes = likes
        self.comments = comments
        self.shares = shares
    }
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
} 
