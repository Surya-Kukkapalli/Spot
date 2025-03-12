import SwiftUI

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showingNewWorkoutSheet = false
    @State private var workoutName = ""
    @State private var showingExerciseSearch = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isWorkoutInProgress {
                    ActiveWorkoutView(viewModel: viewModel)
                } else {
                    WorkoutStartView(
                        showingNewWorkoutSheet: $showingNewWorkoutSheet
                    )
                }
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showingNewWorkoutSheet) {
                NewWorkoutSheet(
                    workoutName: $workoutName,
                    onStart: {
                        viewModel.startNewWorkout(name: workoutName)
                        showingNewWorkoutSheet = false
                    }
                )
            }
        }
    }
}

struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingExerciseSearch = false
    
    var body: some View {
        List {
            // Workout Timer Section
            Section {
                WorkoutTimerView(startTime: viewModel.workoutStartTime ?? Date())
            }
            
            // Exercises Section
            ForEach(viewModel.exercises.indices, id: \.self) { index in
                ExerciseView(exercise: $viewModel.exercises[index], viewModel: viewModel)
            }
            
            Button(action: { showingExerciseSearch = true }) {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
        }
        .sheet(isPresented: $showingExerciseSearch) {
            ExerciseSearchView(viewModel: viewModel)
        }
        .toolbar {
            Button("Finish") {
                Task {
                    try? await viewModel.finishWorkout()
                }
            }
        }
    }
}

struct WorkoutStartView: View {
    @Binding var showingNewWorkoutSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
            
            Text("Ready to crush your workout?")
                .font(.title2)
            
            Button(action: { showingNewWorkoutSheet = true }) {
                Text("Start Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
} 