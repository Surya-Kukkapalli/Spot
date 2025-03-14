import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.workoutSummaries) { summary in
                    WorkoutSummaryCard(workout: summary)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.fetchWorkoutSummaries()
        }
        .task {
            await viewModel.fetchWorkoutSummaries()
        }
        .navigationTitle("Feed")
    }
} 