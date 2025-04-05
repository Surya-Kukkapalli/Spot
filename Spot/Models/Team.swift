import Foundation
import FirebaseFirestore

struct Team: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var creatorId: String
    var imageUrl: String?
    var members: [String]
    var tags: [String]
    var isPrivate: Bool
    var posts: [TeamPost]
    var admins: [String]
    var goals: [TeamGoal]
    
    init(
        id: String? = UUID().uuidString,
        name: String,
        description: String,
        creatorId: String,
        imageUrl: String? = nil,
        members: [String] = [],
        tags: [String] = [],
        isPrivate: Bool = false,
        posts: [TeamPost] = [],
        admins: [String] = [],
        goals: [TeamGoal] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.imageUrl = imageUrl
        self.members = members.isEmpty ? [creatorId] : members
        self.tags = tags
        self.isPrivate = isPrivate
        self.posts = posts
        self.admins = admins.isEmpty ? [creatorId] : admins
        self.goals = goals
    }
    
    // Helper methods
    func isMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
    
    func isAdmin(_ userId: String) -> Bool {
        return admins.contains(userId)
    }
    
    mutating func addMember(_ userId: String) {
        if !members.contains(userId) {
            members.append(userId)
        }
    }
    
    mutating func removeMember(_ userId: String) {
        members.removeAll { $0 == userId }
        admins.removeAll { $0 == userId }
    }
    
    mutating func addAdmin(_ userId: String) {
        if !admins.contains(userId) {
            admins.append(userId)
        }
        if !members.contains(userId) {
            members.append(userId)
        }
    }
    
    mutating func removeAdmin(_ userId: String) {
        guard userId != creatorId else { return } // Can't remove creator from admin
        admins.removeAll { $0 == userId }
    }
}

struct TeamGoal: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var targetDate: Date
    var type: GoalType
    var target: Double
    var unit: String
    var progress: Double
    var isCompleted: Bool
    
    enum GoalType: String, Codable {
        case collective // Team total
        case average // Per member average
        case individual // Each member must achieve
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        targetDate: Date,
        type: GoalType,
        target: Double,
        unit: String,
        progress: Double = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.type = type
        self.target = target
        self.unit = unit
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

struct TeamPost: Identifiable, Codable {
    var id: String
    var content: String
    var authorId: String
    var authorName: String
    var authorImageUrl: String?
    var imageUrl: String?
    var createdAt: Date
    var isAdmin: Bool
    var likes: [String]
    var comments: [Comment]
    
    init(
        id: String = UUID().uuidString,
        content: String,
        authorId: String,
        authorName: String,
        authorImageUrl: String? = nil,
        imageUrl: String? = nil,
        createdAt: Date = Date(),
        isAdmin: Bool = false,
        likes: [String] = [],
        comments: [Comment] = []
    ) {
        self.id = id
        self.content = content
        self.authorId = authorId
        self.authorName = authorName
        self.authorImageUrl = authorImageUrl
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.isAdmin = isAdmin
        self.likes = likes
        self.comments = comments
    }
}


