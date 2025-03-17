import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedWorkout: WorkoutSummary?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.workoutSummaries, id: \.self) { workout in
                        WorkoutSummaryCard(workout: workout)
                            .padding(.vertical, 1)
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                    }
                }
            }
            .background(Color(.systemGray6))
            .task {
                await viewModel.fetchWorkoutSummaries()
            }
            .refreshable {
                await viewModel.fetchWorkoutSummaries()
            }
            .navigationTitle("Home Feed")
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
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