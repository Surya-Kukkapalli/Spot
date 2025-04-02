import Foundation
import FirebaseFirestore

struct Team: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let createdAt: Date
    let creatorId: String
    var members: [String] // User IDs
    var admins: [String] // User IDs with admin privileges
    var imageUrl: String?
    var goals: [TeamGoal]
    var isPrivate: Bool
    
    struct TeamGoal: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let targetDate: Date
        let type: GoalType
        let target: Double
        let unit: String
        var progress: Double
        var isCompleted: Bool
        
        enum GoalType: String, Codable {
            case collective // Team total
            case average // Per member average
            case individual // Each member must achieve
        }
        
        init(id: String = UUID().uuidString,
             title: String,
             description: String,
             targetDate: Date,
             type: GoalType,
             target: Double,
             unit: String,
             progress: Double = 0,
             isCompleted: Bool = false) {
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
    
    init(id: String = UUID().uuidString,
         name: String,
         description: String,
         createdAt: Date = Date(),
         creatorId: String,
         members: [String] = [],
         admins: [String] = [],
         imageUrl: String? = nil,
         goals: [TeamGoal] = [],
         isPrivate: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.creatorId = creatorId
        self.members = members
        self.admins = admins
        self.imageUrl = imageUrl
        self.goals = goals
        self.isPrivate = isPrivate
        
        // Ensure creator is both a member and admin
        if !members.contains(creatorId) {
            self.members.append(creatorId)
        }
        if !admins.contains(creatorId) {
            self.admins.append(creatorId)
        }
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