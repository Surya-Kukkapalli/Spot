import Foundation
import FirebaseFirestore

struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let goal: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    let creatorId: String
    let badgeImageUrl: String?
    let bannerImageUrl: String?
    let callToAction: String?
    let qualifyingMuscles: [String]
    var participants: [String]
    var completions: [String: Double]
    var organizer: Organizer?
    
    struct Organizer: Codable {
        let id: String
        let name: String
        let type: String // "CLUB", "TEAM", "ORGANIZATION"
        let imageUrl: String?
    }
    
    struct LeaderboardEntry: Identifiable, Codable {
        let id: String
        let userId: String
        let username: String
        let userProfileImageUrl: String?
        let progress: Double
        let rank: Int
    }
    
    enum ChallengeType: String, Codable, CaseIterable {
        case distance
        case volume
        case duration
        case count
        
        var iconName: String {
            switch self {
            case .distance:
                return "figure.walk"
            case .volume:
                return "dumbbell.fill"
            case .duration:
                return "clock"
            case .count:
                return "number"
            }
        }
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         type: ChallengeType,
         goal: Double,
         unit: String,
         startDate: Date,
         endDate: Date,
         creatorId: String,
         badgeImageUrl: String? = nil,
         bannerImageUrl: String? = nil,
         callToAction: String? = nil,
         qualifyingMuscles: [String] = [],
         participants: [String] = [],
         completions: [String: Double] = [:],
         organizer: Organizer? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.goal = goal
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.creatorId = creatorId
        self.badgeImageUrl = badgeImageUrl
        self.bannerImageUrl = bannerImageUrl
        self.callToAction = callToAction
        self.qualifyingMuscles = qualifyingMuscles
        self.participants = participants
        self.completions = completions
        self.organizer = organizer
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    func progressForUser(_ userId: String) -> Double {
        completions[userId] ?? 0
    }
    
    func progressPercentageForUser(_ userId: String) -> Double {
        (progressForUser(userId) / goal) * 100
    }
    
    func isCompletedByUser(_ userId: String) -> Bool {
        return progressPercentageForUser(userId) >= 100
    }
    
    var leaderboard: [LeaderboardEntry] {
        let sortedCompletions = completions.sorted { $0.value > $1.value }
        return sortedCompletions.enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.key,
                userId: entry.key,
                username: "User \(index + 1)", // This should be fetched from user data
                userProfileImageUrl: nil,
                progress: entry.value,
                rank: index + 1
            )
        }
    }
    
    var followingLeaderboard: [LeaderboardEntry] {
        // This should be filtered based on the current user's following list
        return leaderboard
    }
    
    func exerciseQualifies(_ exercise: Exercise) -> Bool {
        if qualifyingMuscles.isEmpty {
            return true // If no muscles specified, all exercises qualify
        }
        
        // Check if any of the qualifying muscles are in either target or secondary muscles
        let exerciseMuscles = Set([exercise.target] + exercise.secondaryMuscles)
        return !Set(qualifyingMuscles).isDisjoint(with: exerciseMuscles)
    }
    
    enum CodingKeys: CodingKey {
        case id, title, description, type, goal, unit, startDate, endDate
        case creatorId, badgeImageUrl, bannerImageUrl, callToAction
        case qualifyingMuscles, participants, completions, organizer
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(ChallengeType.self, forKey: .type)
        goal = try container.decode(Double.self, forKey: .goal)
        unit = try container.decode(String.self, forKey: .unit)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        badgeImageUrl = try container.decodeIfPresent(String.self, forKey: .badgeImageUrl)
        bannerImageUrl = try container.decodeIfPresent(String.self, forKey: .bannerImageUrl)
        callToAction = try container.decodeIfPresent(String.self, forKey: .callToAction)
        qualifyingMuscles = try container.decodeIfPresent([String].self, forKey: .qualifyingMuscles) ?? []
        participants = try container.decode([String].self, forKey: .participants)
        completions = try container.decode([String: Double].self, forKey: .completions)
        organizer = try container.decodeIfPresent(Organizer.self, forKey: .organizer)
    }
} 
