import Foundation
import FirebaseFirestore

struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let scope: ChallengeScope
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
    var comments: [Comment]
    
    struct Comment: Identifiable, Codable {
        let id: String
        let userId: String
        let content: String
        let timestamp: Date
        let userProfileImageUrl: String?
        let username: String
    }
    
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
        case volume
        case time
        case oneRepMax = "one_rep_max"
        case personalRecord = "personal_record"
        
        var iconName: String {
            switch self {
            case .volume:
                return "dumbbell.fill"
            case .time:
                return "clock"
            case .oneRepMax:
                return "figure.strengthtraining.traditional"
            case .personalRecord:
                return "trophy.fill"
            }
        }
        
        var displayName: String {
            switch self {
            case .volume:
                return "Volume"
            case .time:
                return "Time"
            case .oneRepMax:
                return "One Rep Max"
            case .personalRecord:
                return "Personal Record"
            }
        }
    }
    
    enum ChallengeScope: String, Codable, CaseIterable {
        case group = "group"
        case competitive = "competitive"
        
        var displayName: String {
            switch self {
            case .group:
                return "Group"
            case .competitive:
                return "Competitive"
            }
        }
        
        var description: String {
            switch self {
            case .group:
                return "Work together towards a shared goal"
            case .competitive:
                return "Compete against each other to reach the goal first"
            }
        }
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         type: ChallengeType,
         scope: ChallengeScope = .competitive,
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
         organizer: Organizer? = nil,
         comments: [Comment] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.scope = scope
        self.goal = goal
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.creatorId = creatorId
        self.badgeImageUrl = badgeImageUrl
        self.bannerImageUrl = bannerImageUrl
        self.callToAction = callToAction
        self.qualifyingMuscles = qualifyingMuscles
        var allParticipants = Set(participants)
        allParticipants.insert(creatorId)
        self.participants = Array(allParticipants)
        self.completions = completions
        self.organizer = organizer
        self.comments = comments
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
    
    var totalProgress: Double {
        switch scope {
        case .group:
            return completions.values.reduce(0, +)
        case .competitive:
            return completions.values.max() ?? 0
        }
    }
    
    var totalProgressPercentage: Double {
        (totalProgress / goal) * 100
    }
    
    var isExpired: Bool {
        Date() > endDate
    }
    
    var isCompleted: Bool {
        switch scope {
        case .group:
            return totalProgress >= goal
        case .competitive:
            return isExpired
        }
    }
    
    var shouldShowInActiveView: Bool {
        !isExpired && !isCompleted
    }
    
    var shouldShowInChallengesView: Bool {
        !isExpired && !isCompleted
    }
    
    func shouldAwardTrophy(userId: String) -> Bool {
        switch scope {
        case .group:
            return isCompleted
        case .competitive:
            return isExpired && isCompletedByUser(userId)
        }
    }
    
    func getRank(for userId: String) -> Int? {
        guard scope == .competitive && isExpired else { return nil }
        let sortedParticipants = completions.sorted { $0.value > $1.value }
        return sortedParticipants.firstIndex { $0.key == userId }.map { $0 + 1 }
    }
    
    enum CodingKeys: CodingKey {
        case id, title, description, type, scope, goal, unit, startDate, endDate
        case creatorId, badgeImageUrl, bannerImageUrl, callToAction
        case qualifyingMuscles, participants, completions, organizer, comments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(ChallengeType.self, forKey: .type)
        scope = try container.decode(ChallengeScope.self, forKey: .scope)
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
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
    }
} 
