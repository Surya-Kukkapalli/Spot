import SwiftUI
import FirebaseFirestore

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showNewWorkoutSheet = false
    @State private var showExerciseSearch = false
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Log Workout")
                .sheet(isPresented: $showNewWorkoutSheet) {
                    NewWorkoutSheet { name in
                        viewModel.startNewWorkout(name: name)
                    }
                }
                .sheet(isPresented: $showExerciseSearch) {
                    NavigationStack {
                        ExerciseView(workoutViewModel: viewModel)
                    }
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
        VStack(spacing: 20) {
            // Stats Section
            HStack(spacing: 40) {
                StatView(title: "Duration", value: formatDuration())
                StatView(title: "Volume", value: "\(calculateVolume()) lbs")
                StatView(title: "Sets", value: "\(calculateTotalSets())")
            }
            .padding(.top)
            
            if viewModel.exercises.isEmpty {
                // Empty State
                Spacer()
                EmptyWorkoutView(showExerciseSearch: $showExerciseSearch)
                Spacer()
            } else {
                // Exercise List
                exerciseList
            }
            
            // Bottom Buttons
            VStack(spacing: 16) {
                addExerciseButton
                finishWorkoutButton
            }
            .padding()
        }
    }
    
    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                    NavigationLink {
                        WorkoutExerciseDetailView(
                            exercise: exercise,
                            viewModel: viewModel,
                            exerciseIndex: index
                        )
                    } label: {
                        ExerciseRowView(exercise: exercise, exerciseIndex: index)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
        }
    }
    
    private var addExerciseButton: some View {
        Button {
            showExerciseSearch = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var finishWorkoutButton: some View {
        Button {
            Task {
                try? await viewModel.finishWorkout()
            }
        } label: {
            Text("Finish")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemBackground))
                .foregroundColor(.blue)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1)
                )
        }
    }
    
    // Helper functions
    private func formatDuration() -> String {
        guard let startTime = viewModel.workoutStartTime else { return "0s" }
        let duration = Int(Date().timeIntervalSince(startTime))
        return "\(duration)s"
    }
    
    private func calculateVolume() -> Int {
        viewModel.exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + Int(set.weight * Double(set.reps))
            }
        }
    }
    
    private func calculateTotalSets() -> Int {
        viewModel.exercises.reduce(0) { $0 + $1.sets.count }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}

struct EmptyWorkoutView: View {
    @Binding var showExerciseSearch: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Get started")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add an exercise to start your workout")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showExerciseSearch = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Exercise")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }
        }
    }
}

// Add this new view for displaying exercise details
struct ExerciseRowView: View {
    let exercise: Exercise
    let exerciseIndex: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(exercise.name)
                .font(.headline)
            Text("Sets: \(exercise.sets.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Add this struct after EmptyWorkoutView
struct NoWorkoutView: View {
    @Binding var showNewWorkoutSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Active Workout")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new workout to begin tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showNewWorkoutSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start New Workout")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    WorkoutView()
} 