import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var selectedMetric: WorkoutMetric = .duration
    @Published var isLoading = false
    @Published var selectedTimeRange = TimeRange.month
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
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
    
    // Calculate total volume across all workouts
    func getTotalVolume() -> Int {
        workoutSummaries.reduce(0) { $0 + $1.totalVolume }
    }
    
    // Calculate total number of PRs across all workouts
    func getTotalPRs() -> Int {
        workoutSummaries.reduce(0) { total, workout in
            total + (workout.personalRecords?.count ?? 0)
        }
    }
    
    func fetchUserWorkouts(for userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("workout_summaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "date", descending: true)
                .getDocuments()
            
            workoutSummaries = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutSummary.self)
            }
        } catch {
            print("Error fetching workouts: \(error)")
        }
    }
    
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> String {
        let imageData = image.jpegData(compressionQuality: 0.8)
        guard let imageData = imageData else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image"])
        }
        
        let filename = "\(userId)_profile.jpg"
        let imageRef = storage.child("profile_images/\(filename)")
        
        _ = try await imageRef.putDataAsync(imageData)
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // Helper method to get chart data based on selected metric
    func getChartData() -> [(date: Date, value: Double)] {
        let sortedWorkouts = workoutSummaries.sorted { $0.date < $1.date }
        
        return sortedWorkouts.map { workout in
            let value: Double = {
                switch selectedMetric {
                case .duration:
                    return Double(workout.duration)
                case .volume:
                    return Double(workout.totalVolume)
                case .reps:
                    return Double(workout.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } })
                }
            }()
            
            return (date: workout.date, value: value)
        }
    }
} 