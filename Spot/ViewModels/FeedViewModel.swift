import SwiftUI
import Firebase
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchWorkoutSummaries() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("workout_summaries")
                .order(by: "date", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            print("Found \(snapshot.documents.count) workout summary documents")
            
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
                    print("Successfully decoded workout summary: \(summary.workoutTitle)")
                    return summary
                } catch {
                    print("Error decoding workout summary document: \(error)")
                    print("Document data that failed to decode: \(document.data())")
                    return nil
                }
            }
            
            print("Successfully decoded \(self.workoutSummaries.count) workout summaries")
        } catch {
            self.error = error.localizedDescription
            print("Error fetching workout summaries: \(error)")
        }
        
        isLoading = false
    }
} 