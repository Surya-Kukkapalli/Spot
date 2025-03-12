import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var fullName: String
    var email: String
    var profileImageUrl: String?
    var bio: String?
    var isInfluencer: Bool
    var followers: Int
    var following: Int
    var createdAt: Date
    
    // Stats
    var workoutsCompleted: Int?
    var totalWorkoutDuration: TimeInterval?
    var averageWorkoutDuration: TimeInterval?
    
    // Computed property for profile display
    var displayName: String {
        username
    }
}