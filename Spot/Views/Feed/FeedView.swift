import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// class FeedViewModel: ObservableObject {
//     @Published var workoutSummaries: [WorkoutSummary] = []
//     @Published var followedUsersWorkouts: [WorkoutSummary] = []
//     private let db = Firestore.firestore()
    
//     @MainActor
//     func fetchWorkouts() async {
//         guard let userId = Auth.auth().currentUser?.uid else { return }
        
//         do {
//             // Fetch current user's workouts
//             let userWorkoutsSnapshot = try await db.collection("workoutSummaries")
//                 .whereField("userId", isEqualTo: userId)
//                 .order(by: "date", descending: true)
//                 .limit(to: 10)
//                 .getDocuments()
            
//             workoutSummaries = userWorkoutsSnapshot.documents.compactMap { try? $0.data(as: WorkoutSummary.self) }
            
//             // Fetch followed users' workouts
//             let userDoc = try await db.collection("users").document(userId).getDocument()
//             if let user = try? userDoc.data(as: User.self),
//                !user.followingIds.isEmpty {
//                 let followedWorkoutsSnapshot = try await db.collection("workoutSummaries")
//                     .whereField("userId", in: user.followingIds)
//                     .order(by: "date", descending: true)
//                     .limit(to: 20)
//                     .getDocuments()
                
//                 followedUsersWorkouts = followedWorkoutsSnapshot.documents.compactMap { try? $0.data(as: WorkoutSummary.self) }
//             }
//         } catch {
//             print("Error fetching workouts: \(error)")
//         }
//     }
// }

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedWorkout: WorkoutSummary?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if viewModel.workoutSummaries.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Follow other users to see their workouts here")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink(destination: PublicWorkoutsView(userId: authViewModel.currentUser?.id ?? "")) {
                            Text("Discover Users")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.workoutSummaries) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutSummaryCard(workout: workout)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Feed")
            .refreshable {
                await viewModel.fetchWorkoutSummaries()
            }
            .task {
                await viewModel.fetchWorkoutSummaries()
            }
        }
    }
}

// import SwiftUI

// struct FeedView: View {
//     @StateObject private var viewModel = FeedViewModel()
    
//     var body: some View {
//         ScrollView {
//             LazyVStack(spacing: 16) {
//                 ForEach(viewModel.workoutSummaries) { summary in
//                     WorkoutSummaryCard(workout: summary)
//                 }
                
//                 if viewModel.isLoading {
//                     ProgressView()
//                         .padding()
//                 }
//             }
//             .padding()
//         }
//         .refreshable {
//             await viewModel.fetchWorkoutSummaries()
//         }
//         .task {
//             await viewModel.fetchWorkoutSummaries()
//         }
//         .navigationTitle("Feed")
//     }
// } 
