import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedViewModel: ObservableObject {
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchWorkoutSummaries() async {
        isLoading = true
        workoutSummaries = [] // Clear existing workouts
        
        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                error = "User not logged in"
                isLoading = false
                return
            }
            
            // Fetch current user's workouts
            let userWorkoutsSnapshot = try await db.collection("workoutSummaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            print("Found \(userWorkoutsSnapshot.documents.count) user workouts")
            
            var allWorkouts = userWorkoutsSnapshot.documents.compactMap { document in
                do {
                    return try document.data(as: WorkoutSummary.self)
                } catch {
                    print("Error decoding workout summary: \(error)")
                    return nil
                }
            }
            
            // Fetch followed users' workouts if any
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let user = try userDoc.data(as: User.self)
            
            if !user.followingIds.isEmpty {
                print("Fetching workouts for \(user.followingIds.count) followed users")
                
                let followedWorkoutsSnapshot = try await db.collection("workoutSummaries")
                    .whereField("userId", in: user.followingIds)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                
                print("Found \(followedWorkoutsSnapshot.documents.count) followed user workouts")
                
                let followedWorkouts = followedWorkoutsSnapshot.documents.compactMap { document in
                    do {
                        return try document.data(as: WorkoutSummary.self)
                    } catch {
                        print("Error decoding followed workout summary: \(error)")
                        return nil
                    }
                }
                
                allWorkouts.append(contentsOf: followedWorkouts)
            }
            
            // Sort all workouts by date
            allWorkouts.sort { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                self.workoutSummaries = allWorkouts
                print("Total workouts loaded: \(allWorkouts.count)")
            }
        } catch {
            print("Error fetching workouts: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
} 