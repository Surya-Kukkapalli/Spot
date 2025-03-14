import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var firstName: String
    var lastName: String
    var email: String
    var profileImageUrl: String?
    var bio: String?
    var isInfluencer: Bool?
    var followers: Int?
    var following: Int?
    var createdAt: Date?
    
    // Stats
    var workoutsCompleted: Int?
    var totalWorkoutDuration: TimeInterval?
    var averageWorkoutDuration: TimeInterval?
    var personalRecords: [String: PersonalRecord]?
    
    struct PersonalRecord: Codable {
        let weight: Double
        let reps: Int
        let date: Date
    }
    
    // Computed properties
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        username
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName
        case lastName
        case email
        case profileImageUrl
        case bio
        case isInfluencer
        case followers
        case following
        case createdAt
        case workoutsCompleted
        case totalWorkoutDuration
        case averageWorkoutDuration
        case personalRecords
    }
}