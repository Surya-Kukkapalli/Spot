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
            
            print("DEBUG: Fetching workouts for feed - user: \(userId)")
            
            // First try workoutSummaries collection for current user
            let userSummariesSnapshot = try await db.collection("workoutSummaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(userSummariesSnapshot.documents.count) user workout summaries")
            
            var allWorkouts = userSummariesSnapshot.documents.compactMap { document -> WorkoutSummary? in
                do {
                    let summary = try document.data(as: WorkoutSummary.self)
                    print("DEBUG: Successfully decoded workout summary: \(summary.workoutTitle)")
                    return summary
                } catch {
                    print("DEBUG: Error decoding workout summary: \(error)")
                    return nil
                }
            }
            
            // If no summaries found, try workouts collection
            if allWorkouts.isEmpty {
                print("DEBUG: No workout summaries found, checking workouts collection")
                let workoutsSnapshot = try await db.collection("workouts")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                print("DEBUG: Found \(workoutsSnapshot.documents.count) workouts")
                
                // Convert Workouts to WorkoutSummaries
                let workouts = workoutsSnapshot.documents.compactMap { document -> Workout? in
                    do {
                        var workout = try document.data(as: Workout.self)
                        workout.id = document.documentID
                        print("DEBUG: Successfully decoded workout: \(workout.name)")
                        return workout
                    } catch {
                        print("DEBUG: Error decoding workout: \(error)")
                        return nil
                    }
                }
                
                // Get user data for creating summaries
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let user = try? userDoc.data(as: User.self) {
                    let userWorkouts = workouts.map { workout in
                        print("DEBUG: Converting workout to summary: \(workout.name)")
                        return createWorkoutSummary(from: workout, user: user)
                    }
                    allWorkouts.append(contentsOf: userWorkouts)
                }
            }
            
            // Fetch followed users' workouts if any
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let user = try userDoc.data(as: User.self)
            
            if !user.followingIds.isEmpty {
                print("DEBUG: Fetching workouts for \(user.followingIds.count) followed users")
                
                // Try workoutSummaries collection for followed users
                let followedSummariesSnapshot = try await db.collection("workoutSummaries")
                    .whereField("userId", in: user.followingIds)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                print("DEBUG: Found \(followedSummariesSnapshot.documents.count) followed user workout summaries")
                
                let followedSummaries = followedSummariesSnapshot.documents.compactMap { document -> WorkoutSummary? in
                    do {
                        return try document.data(as: WorkoutSummary.self)
                    } catch {
                        print("DEBUG: Error decoding followed workout summary: \(error)")
                        return nil
                    }
                }
                
                allWorkouts.append(contentsOf: followedSummaries)
                
                // If no summaries found for followed users, try workouts collection
                if followedSummaries.isEmpty {
                    print("DEBUG: No workout summaries found for followed users, checking workouts collection")
                    let followedWorkoutsSnapshot = try await db.collection("workouts")
                        .whereField("userId", in: user.followingIds)
                        .order(by: "createdAt", descending: true)
                        .getDocuments()
                    
                    let followedWorkouts = followedWorkoutsSnapshot.documents.compactMap { document -> Workout? in
                        do {
                            var workout = try document.data(as: Workout.self)
                            workout.id = document.documentID
                            return workout
                        } catch {
                            print("DEBUG: Error decoding followed workout: \(error)")
                            return nil
                        }
                    }
                    
                    // Get user data and convert workouts to summaries
                    for workout in followedWorkouts {
                        if let followedUserDoc = try? await db.collection("users").document(workout.userId).getDocument(),
                           let followedUser = try? followedUserDoc.data(as: User.self) {
                            let summary = createWorkoutSummary(from: workout, user: followedUser)
                            allWorkouts.append(summary)
                        }
                    }
                }
            }
            
            // Sort all workouts by date
            allWorkouts.sort { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                self.workoutSummaries = allWorkouts
                print("DEBUG: Total workouts loaded for feed: \(allWorkouts.count)")
            }
        } catch {
            print("DEBUG: Error fetching workouts: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createWorkoutSummary(from workout: Workout, user: User) -> WorkoutSummary {
        // Create exercise summaries
        let exerciseSummaries = workout.exercises.map { exercise -> WorkoutSummary.Exercise in
            let sets = exercise.sets.map { set -> WorkoutSummary.Exercise.Set in
                WorkoutSummary.Exercise.Set(
                    weight: set.weight,
                    reps: set.reps,
                    isPR: set.isPR
                )
            }
            
            return WorkoutSummary.Exercise(
                exerciseName: exercise.name,
                imageUrl: exercise.gifUrl,
                targetMuscle: exercise.target ?? "Other",
                sets: sets,
                hasPR: sets.contains { $0.isPR }
            )
        }
        
        // Create personal records dictionary from exercises with PRs
        var personalRecords: [String: PersonalRecord] = [:]
        for exercise in workout.exercises {
            if let bestSet = exercise.sets.first(where: { $0.isPR }) {
                personalRecords[exercise.name] = PersonalRecord(
                    id: UUID().uuidString,
                    exerciseName: exercise.name,
                    weight: bestSet.weight,
                    reps: bestSet.reps,
                    oneRepMax: OneRepMax.calculate(weight: bestSet.weight, reps: bestSet.reps),
                    date: workout.createdAt,
                    workoutId: workout.id,
                    userId: user.id ?? ""
                )
            }
        }
        
        return WorkoutSummary(
            id: workout.id,
            userId: user.id ?? "",
            username: user.username,
            userProfileImageUrl: user.profileImageUrl,
            workoutTitle: workout.name,
            workoutNotes: workout.notes,
            createdAt: workout.createdAt,
            duration: Int(workout.duration / 60), // Convert seconds to minutes
            totalVolume: calculateVolume(exercises: workout.exercises),
            fistBumps: workout.likes ?? 0,
            comments: workout.comments ?? 0,
            exercises: exerciseSummaries,
            personalRecords: personalRecords
        )
    }
    
    private func calculateVolume(exercises: [Exercise]) -> Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + Int(set.weight * Double(set.reps))
            }
        }
    }
} 