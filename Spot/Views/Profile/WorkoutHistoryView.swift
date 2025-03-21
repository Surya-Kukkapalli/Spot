import SwiftUI

struct WorkoutHistoryView: View {
    let userId: String
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if viewModel.workoutSummaries.isEmpty {
                    Text("No workouts yet")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.workoutSummaries) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutSummaryCard(workout: workout)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Workout History")
        .task {
            await viewModel.fetchUserWorkouts(for: userId)
        }
        .refreshable {
            await viewModel.fetchUserWorkouts(for: userId)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryView(userId: "testUserId")
    }
} 