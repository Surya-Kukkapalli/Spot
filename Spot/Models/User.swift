import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String?
    var username: String
    let email: String
    var profileImageUrl: String?
    var bio: String?
    var firstName: String?
    var lastName: String?
    var isInfluencer: Bool?
    var followers: Int
    var following: Int
    var createdAt: Date
    var updatedAt: Date
    var followingIds: [String]
    var followerIds: [String]
    var workoutsCompleted: Int?
    var totalWorkoutDuration: TimeInterval?
    var averageWorkoutDuration: TimeInterval?
    var personalRecords: [String: PersonalRecord]?
    var exerciseOneRepMaxes: [String: OneRepMax]?
    var fitnessProfile: UserFitnessProfile?
    
    struct PersonalRecord: Codable {
        let weight: Double
        let reps: Int
        let date: Date
    }
    
    struct OneRepMax: Codable {
        let weight: Double
        let date: Date
    }
    
    // Computed properties
    var name: String? {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        }
        return nil
    }
    
    var fullName: String {
        name ?? ""
    }
    
    var displayName: String {
        username
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case profileImageUrl
        case bio
        case firstName
        case lastName
        case isInfluencer
        case followers
        case following
        case createdAt
        case updatedAt
        case followingIds
        case followerIds
        case workoutsCompleted
        case totalWorkoutDuration
        case averageWorkoutDuration
        case personalRecords
        case exerciseOneRepMaxes
        case fitnessProfile
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id from the container, otherwise it will be set by Firestore
        id = try container.decodeIfPresent(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        isInfluencer = try container.decodeIfPresent(Bool.self, forKey: .isInfluencer)
        followers = try container.decodeIfPresent(Int.self, forKey: .followers) ?? 0
        following = try container.decodeIfPresent(Int.self, forKey: .following) ?? 0
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
        followingIds = try container.decodeIfPresent([String].self, forKey: .followingIds) ?? []
        followerIds = try container.decodeIfPresent([String].self, forKey: .followerIds) ?? []
        workoutsCompleted = try container.decodeIfPresent(Int.self, forKey: .workoutsCompleted)
        totalWorkoutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalWorkoutDuration)
        averageWorkoutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .averageWorkoutDuration)
        personalRecords = try container.decodeIfPresent([String: PersonalRecord].self, forKey: .personalRecords)
        exerciseOneRepMaxes = try container.decodeIfPresent([String: OneRepMax].self, forKey: .exerciseOneRepMaxes)
        fitnessProfile = try container.decodeIfPresent(UserFitnessProfile.self, forKey: .fitnessProfile)
        
        // Handle first and last name
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(followers, forKey: .followers)
        try container.encode(following, forKey: .following)
        try container.encode(followingIds, forKey: .followingIds)
        try container.encode(followerIds, forKey: .followerIds)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        if let id = id { try container.encode(id, forKey: .id) }
        if let firstName = firstName { try container.encode(firstName, forKey: .firstName) }
        if let lastName = lastName { try container.encode(lastName, forKey: .lastName) }
        if let profileImageUrl = profileImageUrl { try container.encode(profileImageUrl, forKey: .profileImageUrl) }
        if let bio = bio { try container.encode(bio, forKey: .bio) }
        if let isInfluencer = isInfluencer { try container.encode(isInfluencer, forKey: .isInfluencer) }
        if let workoutsCompleted = workoutsCompleted { try container.encode(workoutsCompleted, forKey: .workoutsCompleted) }
        if let totalWorkoutDuration = totalWorkoutDuration { try container.encode(totalWorkoutDuration, forKey: .totalWorkoutDuration) }
        if let averageWorkoutDuration = averageWorkoutDuration { try container.encode(averageWorkoutDuration, forKey: .averageWorkoutDuration) }
        if let personalRecords = personalRecords { try container.encode(personalRecords, forKey: .personalRecords) }
        if let exerciseOneRepMaxes = exerciseOneRepMaxes { try container.encode(exerciseOneRepMaxes, forKey: .exerciseOneRepMaxes) }
        if let fitnessProfile = fitnessProfile { try container.encode(fitnessProfile, forKey: .fitnessProfile) }
    }
    
    init(id: String? = nil,
         username: String,
         firstName: String? = nil,
         lastName: String? = nil,
         email: String,
         profileImageUrl: String? = nil,
         bio: String? = nil,
         isInfluencer: Bool? = nil,
         followers: Int = 0,
         following: Int = 0,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         followingIds: [String] = [],
         followerIds: [String] = [],
         workoutsCompleted: Int? = nil,
         totalWorkoutDuration: TimeInterval? = nil,
         averageWorkoutDuration: TimeInterval? = nil,
         personalRecords: [String: PersonalRecord]? = nil,
         exerciseOneRepMaxes: [String: OneRepMax]? = nil,
         fitnessProfile: UserFitnessProfile? = nil) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.profileImageUrl = profileImageUrl
        self.bio = bio
        self.isInfluencer = isInfluencer
        self.followers = followers
        self.following = following
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.followingIds = followingIds
        self.followerIds = followerIds
        self.workoutsCompleted = workoutsCompleted
        self.totalWorkoutDuration = totalWorkoutDuration
        self.averageWorkoutDuration = averageWorkoutDuration
        self.personalRecords = personalRecords
        self.exerciseOneRepMaxes = exerciseOneRepMaxes
        self.fitnessProfile = fitnessProfile
    }
    
    init?(dictionary: [String: Any]) {
        guard let username = dictionary["username"] as? String,
              let email = dictionary["email"] as? String else {
            return nil
        }
        
        self.id = dictionary["id"] as? String
        self.username = username
        self.firstName = dictionary["firstName"] as? String
        self.lastName = dictionary["lastName"] as? String
        self.email = email
        self.profileImageUrl = dictionary["profileImageUrl"] as? String
        self.bio = dictionary["bio"] as? String
        self.isInfluencer = dictionary["isInfluencer"] as? Bool
        self.followers = dictionary["followers"] as? Int ?? 0
        self.following = dictionary["following"] as? Int ?? 0
        self.followerIds = dictionary["followerIds"] as? [String] ?? []
        self.followingIds = dictionary["followingIds"] as? [String] ?? []
        self.createdAt = (dictionary["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.workoutsCompleted = dictionary["workoutsCompleted"] as? Int
        self.totalWorkoutDuration = dictionary["totalWorkoutDuration"] as? TimeInterval
        self.averageWorkoutDuration = dictionary["averageWorkoutDuration"] as? TimeInterval
        self.personalRecords = dictionary["personalRecords"] as? [String: PersonalRecord]
        self.exerciseOneRepMaxes = dictionary["exerciseOneRepMaxes"] as? [String: OneRepMax]
        self.fitnessProfile = dictionary["fitnessProfile"] as? UserFitnessProfile
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "username": username,
            "email": email,
            "followers": followers,
            "following": following,
            "followerIds": followerIds,
            "followingIds": followingIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "workoutsCompleted": workoutsCompleted ?? 0,
            "totalWorkoutDuration": totalWorkoutDuration ?? 0,
            "averageWorkoutDuration": averageWorkoutDuration ?? 0
        ]
        
        if let id = id { dict["id"] = id }
        if let firstName = firstName { dict["firstName"] = firstName }
        if let lastName = lastName { dict["lastName"] = lastName }
        if let profileImageUrl = profileImageUrl { dict["profileImageUrl"] = profileImageUrl }
        if let bio = bio { dict["bio"] = bio }
        if let isInfluencer = isInfluencer { dict["isInfluencer"] = isInfluencer }
        if let workoutsCompleted = workoutsCompleted { dict["workoutsCompleted"] = workoutsCompleted }
        if let totalWorkoutDuration = totalWorkoutDuration { dict["totalWorkoutDuration"] = totalWorkoutDuration }
        if let averageWorkoutDuration = averageWorkoutDuration { dict["averageWorkoutDuration"] = averageWorkoutDuration }
        if let personalRecords = personalRecords { dict["personalRecords"] = personalRecords }
        if let exerciseOneRepMaxes = exerciseOneRepMaxes { dict["exerciseOneRepMaxes"] = exerciseOneRepMaxes }
        if let fitnessProfile = fitnessProfile { dict["fitnessProfile"] = fitnessProfile }
        
        return dict
    }
}
