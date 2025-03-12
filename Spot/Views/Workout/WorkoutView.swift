import SwiftUI
import FirebaseFirestore

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showNewWorkoutSheet = false
    @State private var showExerciseSearch = false
    @State private var selectedExerciseIndex: Int?
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Workout")
                .sheet(isPresented: $showNewWorkoutSheet) {
                    NewWorkoutSheet { name in
                        viewModel.startNewWorkout(name: name)
                    }
                }
                .sheet(isPresented: $showExerciseSearch) {
                    ExerciseSearchView(viewModel: viewModel)
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isWorkoutInProgress {
            ActiveWorkoutView(
                viewModel: viewModel,
                showExerciseSearch: $showExerciseSearch
            )
        } else {
            NoWorkoutView(showNewWorkoutSheet: $showNewWorkoutSheet)
        }
    }
}

// MARK: - Subviews
private struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Binding var showExerciseSearch: Bool
    
    var body: some View {
        VStack {
            // Workout Timer
            WorkoutTimerView(startTime: viewModel.workoutStartTime ?? Date())
                .padding()
            
            // Exercise List
            List {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseView(
                        exercise: exercise,
                        exerciseIndex: index,
                        viewModel: viewModel
                    )
                }
            }
            
            // Bottom Buttons
            VStack(spacing: 16) {
                Button {
                    showExerciseSearch = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                
                Button {
                    Task {
                        try? await viewModel.finishWorkout()
                    }
                } label: {
                    Text("Finish Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

private struct NoWorkoutView: View {
    @Binding var showNewWorkoutSheet: Bool
    
    var body: some View {
        VStack {
            Text("No Active Workout")
                .font(.title)
                .foregroundColor(.secondary)
            
            Button {
                showNewWorkoutSheet = true
            } label: {
                Label("Start New Workout", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .padding()
        }
    }
}

#Preview {
    WorkoutView()
} 