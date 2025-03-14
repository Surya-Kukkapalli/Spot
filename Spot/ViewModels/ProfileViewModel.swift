import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var isLoading = false
    @Published var selectedTimeRange = TimeRange.month
    @Published var selectedMetric = WorkoutMetric.duration
    
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
    
    func fetchUserWorkouts(for userId: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("workout_summaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "date", descending: true)
                .getDocuments()
            
            self.workoutSummaries = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutSummary.self)
            }
        } catch {
            print("Error fetching workouts: \(error)")
        }
        
        isLoading = false
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
} 