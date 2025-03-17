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
        print("Starting workout fetch for user: \(userId)")
        
        do {
            let snapshot = try await db.collection("workout_summaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "date", descending: true)
                .getDocuments()
            
            print("Found \(snapshot.documents.count) workout documents")
            
            self.workoutSummaries = snapshot.documents.compactMap { document in
                do {
                    print("Attempting to decode document: \(document.documentID)")
                    print("Document data: \(document.data())")
                    
                    // Create a mutable copy of the document data
                    var data = document.data()
                    // Add the document ID to the data dictionary
                    data["id"] = document.documentID
                    
                    // Create a custom decoder that can handle Firestore types
                    let decoder = Firestore.Decoder()
                    let summary = try decoder.decode(WorkoutSummary.self, from: data)
                    print("Successfully decoded workout: \(summary.workoutTitle)")
                    return summary
                } catch {
                    print("Error decoding workout document: \(error)")
                    print("Document data that failed to decode: \(document.data())")
                    return nil
                }
            }
            
            print("Successfully decoded \(self.workoutSummaries.count) workouts")
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