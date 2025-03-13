import SwiftUI
import FirebaseFirestore

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showNewWorkoutSheet = false
    @State private var showExerciseSearch = false
    @State private var showSaveWorkout = false
    
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
                showExerciseSearch: $showExerciseSearch,
                showSaveWorkout: $showSaveWorkout
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
    @Binding var showSaveWorkout: Bool
    
    var body: some View {
        ScrollView {
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
                    EmptyWorkoutView(showExerciseSearch: $showExerciseSearch)
                        .padding(.vertical, 40)
                } else {
                    // Exercise List
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                            WorkoutExerciseView(workoutViewModel: viewModel, exerciseIndex: index)
                        }
                    }
                    .padding()
                }
                
                // Bottom Buttons
                VStack(spacing: 16) {
                    addExerciseButton
                    finishWorkoutButton
                }
                .padding()
            }
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
            showSaveWorkout = true
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
        .sheet(isPresented: $showSaveWorkout) {
            SaveWorkoutView(viewModel: viewModel)
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
            
            /*
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
            */
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

// Update WorkoutExerciseView to include sets
struct WorkoutExerciseView: View {
    @ObservedObject var workoutViewModel: WorkoutViewModel
    let exerciseIndex: Int
    @State private var showingOptions = false
    
    private var exercise: Exercise {
        guard workoutViewModel.exercises.indices.contains(exerciseIndex) else {
            return Exercise(id: "", name: "", sets: [], equipment: .bodyweight)
        }
        return workoutViewModel.exercises[exerciseIndex]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise Header
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                Text(exercise.name.capitalized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button(role: .destructive) {
                        withAnimation {
                            workoutViewModel.removeExercise(at: exerciseIndex)
                        }
                    } label: {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            
            // Notes TextField
            TextField("Add notes here...", text: Binding(
                get: { exercise.notes ?? "" },
                set: { workoutViewModel.exercises[exerciseIndex].notes = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)
            
            // Rest Timer Toggle (to be implemented)
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Rest Timer: OFF")
                    .foregroundColor(.blue)
            }
            
            // Sets Header
            HStack {
                Text("SET")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Text("PREVIOUS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                
                Text("LBS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                Text("REPS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                Spacer()
            }
            .padding(.top, 8)
            
            // Sets List
            ForEach(exercise.sets.indices, id: \.self) { setIndex in
                if workoutViewModel.exercises.indices.contains(exerciseIndex) &&
                   workoutViewModel.exercises[exerciseIndex].sets.indices.contains(setIndex) {
                    SetRowView(
                        set: Binding(
                            get: { 
                                guard workoutViewModel.exercises.indices.contains(exerciseIndex),
                                      workoutViewModel.exercises[exerciseIndex].sets.indices.contains(setIndex) else {
                                    return ExerciseSet(id: UUID().uuidString)
                                }
                                return workoutViewModel.exercises[exerciseIndex].sets[setIndex]
                            },
                            set: { newValue in
                                guard workoutViewModel.exercises.indices.contains(exerciseIndex),
                                      workoutViewModel.exercises[exerciseIndex].sets.indices.contains(setIndex) else {
                                    return
                                }
                                workoutViewModel.exercises[exerciseIndex].sets[setIndex] = newValue
                            }
                        ),
                        setNumber: setIndex + 1,
                        previousSet: setIndex > 0 ? exercise.sets[setIndex - 1] : nil,
                        onDelete: {
                            withAnimation {
                                workoutViewModel.removeSet(from: exerciseIndex, at: setIndex)
                            }
                        }
                    )
                }
            }
            
            // Add Set Button
            Button {
                workoutViewModel.addSet(to: exerciseIndex)
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Set")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// Add this new view for the set row
struct SetRowView: View {
    @Binding var set: ExerciseSet
    let setNumber: Int
    let previousSet: ExerciseSet?
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Set Number
            Text("\(setNumber)")
                .frame(width: 40, alignment: .leading)
                .foregroundColor(.secondary)
            
            // Previous Set
            Text(previousSet.map { "\(Int($0.weight)) × \($0.reps)" } ?? "-")
                .frame(width: 80)
                .foregroundColor(.secondary)
            
            // Weight
            TextField("0", value: $set.weight, formatter: NumberFormatter())
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
            
            // Reps
            TextField("0", value: $set.reps, formatter: NumberFormatter())
                .keyboardType(.numberPad)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
            
            Spacer()
            
            // Completion Checkbox
            Button {
                set.isCompleted.toggle()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .blue : .gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    WorkoutView()
} 
