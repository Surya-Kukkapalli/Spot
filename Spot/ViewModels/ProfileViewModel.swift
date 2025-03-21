import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var user: User?
    @Published var selectedMetric: WorkoutMetric = .duration
    @Published var isLoading = false
    @Published var selectedTimeRange = TimeRange.month
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    enum WorkoutMetric: String, CaseIterable {
        case duration = "Duration"
        case volume = "Volume"
        case reps = "Reps"
    }
    
    func fetchUserWorkouts(for userId: String) async {
        isLoading = true
        guard !userId.isEmpty else { 
            print("DEBUG: No user ID available for fetching workouts")
            isLoading = false
            return 
        }
        
        do {
            print("DEBUG: Fetching workouts for user: \(userId)")
            
            // First try workoutSummaries collection
            let summariesSnapshot = try await db.collection("workoutSummaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(summariesSnapshot.documents.count) workout summaries")
            print("DEBUG: Raw workout summaries data:")
            for doc in summariesSnapshot.documents {
                print("DEBUG: Document ID: \(doc.documentID)")
                print("DEBUG: Document data: \(doc.data())")
            }
            
            var summaries = summariesSnapshot.documents.compactMap { document -> WorkoutSummary? in
                do {
                    let summary = try document.data(as: WorkoutSummary.self)
                    print("DEBUG: Successfully decoded workout summary: \(summary.workoutTitle)")
                    print("DEBUG: Created at: \(summary.createdAt)")
                    return summary
                } catch {
                    print("DEBUG: Error decoding workout summary: \(error)")
                    print("DEBUG: Raw data: \(document.data())")
                    return nil
                }
            }
            
            // If no summaries found, try workouts collection
            if summaries.isEmpty {
                print("DEBUG: No workout summaries found, checking workouts collection")
                let workoutsSnapshot = try await db.collection("workouts")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                print("DEBUG: Found \(workoutsSnapshot.documents.count) workouts")
                print("DEBUG: Raw workouts data:")
                for doc in workoutsSnapshot.documents {
                    print("DEBUG: Document ID: \(doc.documentID)")
                    print("DEBUG: Document data: \(doc.data())")
                }
                
                // Convert Workouts to WorkoutSummaries
                let workouts = workoutsSnapshot.documents.compactMap { document -> Workout? in
                    do {
                        var workout = try document.data(as: Workout.self)
                        workout.id = document.documentID
                        print("DEBUG: Successfully decoded workout: \(workout.name)")
                        return workout
                    } catch {
                        print("DEBUG: Error decoding workout: \(error)")
                        print("DEBUG: Raw data: \(document.data())")
                        return nil
                    }
                }
                
                // Get user data for creating summaries
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let user = try? userDoc.data(as: User.self) {
                    summaries = workouts.map { workout in
                        print("DEBUG: Converting workout to summary: \(workout.name)")
                        return createWorkoutSummary(from: workout, user: user)
                    }
                }
            }
            
            print("DEBUG: Successfully decoded \(summaries.count) workout summaries")
            
            await MainActor.run {
                self.workoutSummaries = summaries
                self.isLoading = false
                print("DEBUG: Total workouts loaded: \(summaries.count)")
            }
            
        } catch {
            print("DEBUG: Error fetching workouts: \(error)")
            isLoading = false
        }
    }
    
    func fetchUser(userId: String) async {
        do {
            print("DEBUG: Fetching user with ID: \(userId)")
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if let userData = userDoc.data() {
                print("DEBUG: Raw user data: \(userData)")
            }
            
            user = try userDoc.data(as: User.self)
            print("DEBUG: User fetched successfully: \(user?.username ?? "unknown")")
            
            // After fetching user, fetch their workouts
            await fetchUserWorkouts(for: userId)
        } catch {
            print("Error fetching user: \(error)")
        }
    }
    
    private func createWorkoutSummary(from workout: Workout, user: User) -> WorkoutSummary {
        // Create exercise summaries
        let exerciseSummaries = workout.exercises.map { exercise -> WorkoutSummary.Exercise in
            return WorkoutSummary.Exercise(
                exerciseName: exercise.name,
                imageUrl: exercise.gifUrl,
                targetMuscle: exercise.target,
                sets: exercise.sets.map { set in
                    WorkoutSummary.Exercise.Set(
                        weight: set.weight,
                        reps: set.reps
                    )
                }
            )
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
            personalRecords: [:] // We'll handle PRs separately if needed
        )
    }
    
    private func calculateVolume(exercises: [Exercise]) -> Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + Int(set.weight * Double(set.reps))
            }
        }
    }
    
    func uploadProfileImage(_ image: UIImage) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let storageRef = storage.reference().child("profile_images/\(userId).jpg")
            let _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            try await db.collection("users").document(userId).updateData([
                "profileImageUrl": downloadURL.absoluteString,
                "updatedAt": Date()
            ])
        } catch {
            print("Error uploading profile image: \(error)")
        }
    }
    
    // Calculate total volume across all workouts
    func getTotalVolume() -> Int {
        workoutSummaries.reduce(0) { $0 + ($1.totalVolume ?? 0) }
    }
    
    // Calculate total number of PRs across all workouts
    func getTotalPRs() -> Int {
        workoutSummaries.reduce(0) { $0 + ($1.personalRecords?.count ?? 0) }
    }
    
    // Helper method to get chart data based on selected metric
    func getChartData() -> [(date: Date, value: Double)] {
        let sortedWorkouts = workoutSummaries.sorted { $0.createdAt < $1.createdAt }
        
        return sortedWorkouts.map { workout in
            let value: Double = {
                switch selectedMetric {
                case .duration:
                    return Double(workout.duration)
                case .volume:
                    return Double(workout.totalVolume ?? 0)
                case .reps:
                    return Double(workout.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } })
                }
            }()
            
            return (date: workout.createdAt, value: value)
        }
    }
} 
