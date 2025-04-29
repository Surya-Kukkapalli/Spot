import SwiftUI
import FirebaseFirestore

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showExerciseSearch = false
    @State private var showSaveWorkout = false
    @State private var isTransitioning = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isWorkoutInProgress {
                    let _ = print("DEBUG: Showing ActiveWorkoutView with \(viewModel.exercises.count) exercises")
                    ActiveWorkoutView(
                        viewModel: viewModel,
                        showExerciseSearch: $showExerciseSearch,
                        showSaveWorkout: $showSaveWorkout
                    )
                    .navigationTitle("Log Workout")
                    .sheet(isPresented: $showExerciseSearch) {
                        NavigationStack {
                            ExerciseSearchView(workoutViewModel: viewModel)
                        }
                    }
                    .sheet(isPresented: $showSaveWorkout) {
                        SaveWorkoutView(viewModel: viewModel)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .onAppear {
                        print("DEBUG: ActiveWorkoutView appeared")
                        print("DEBUG: Current exercise count: \(viewModel.exercises.count)")
                    }
                } else {
                    let _ = print("DEBUG: Showing WorkoutProgramView")
                    WorkoutProgramView()
                        .environment(\.workoutViewModel, viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isWorkoutInProgress)
        }
        .onChange(of: viewModel.isWorkoutInProgress) { newValue in
            print("DEBUG: isWorkoutInProgress changed to: \(newValue)")
            print("DEBUG: Current exercise count: \(viewModel.exercises.count)")
        }
        .onChange(of: viewModel.exercises) { newValue in
            print("DEBUG: Exercises array changed")
            print("DEBUG: New exercise count: \(newValue.count)")
            print("DEBUG: Exercise names: \(newValue.map { $0.name })")
        }
    }
}

private struct WorkoutViewModelKey: EnvironmentKey {
    static let defaultValue: WorkoutViewModel? = nil
}

extension EnvironmentValues {
    var workoutViewModel: WorkoutViewModel? {
        get { self[WorkoutViewModelKey.self] }
        set { self[WorkoutViewModelKey.self] = newValue }
    }
}

// MARK: - Subviews
private struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Binding var showExerciseSearch: Bool
    @Binding var showSaveWorkout: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats Section
                HStack(spacing: 40) {
                    StatView(title: "Duration", value: formatDuration())
                    StatView(title: "Volume", value: "\(calculateVolume()) lbs")
                    StatView(title: "Sets", value: "\(calculateTotalSets())")
                }
                .padding(.top)
                
                // Exercise List
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack {
                            WorkoutExerciseView(workoutViewModel: viewModel, exerciseIndex: index)
                                .padding(.horizontal)
                        }
                        .transition(.opacity.combined(with: .slide))
                    }
                }
                
                // Add Exercise Button
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
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDiscardAlert = true
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Log Workout")
                    .font(.system(.headline, design: .rounded))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showSaveWorkout = true
                    } label: {
                        Text("Finish")
                            .font(.system(.body, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .alert("Discard Workout?", isPresented: $showingDiscardAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                Task {
                    await viewModel.discardWorkout()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to discard this workout? This action cannot be undone.")
        }
        .onAppear {
            print("DEBUG: ActiveWorkoutView appeared")
            print("DEBUG: Current exercise count: \(viewModel.exercises.count)")
            print("DEBUG: Exercise names: \(viewModel.exercises.map { $0.name })")
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
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded))
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

// Update WorkoutExerciseView to include sets
struct WorkoutExerciseView: View {
    @ObservedObject var workoutViewModel: WorkoutViewModel
    let exerciseIndex: Int
    @State private var showingOptions = false
    @State private var isRestTimerActive = false
    @State private var showRestTimerSheet = false
    
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
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                .transition(.scale.combined(with: .opacity))
                
                NavigationLink(destination: ExerciseDetailsView(exercise: exercise.toTemplate())) {
                    HStack(spacing: 4) {
                        Text(exercise.name.capitalized)
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.leading)
                        
                        // For now, we don't want the equipment type
//                        Text("(\(exercise.equipment.description.capitalized))")
//                            .font(.system(.title3, design: .rounded))
//                            .foregroundColor(.secondary)
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                
                Spacer()
                
                Menu {
                    Button {
                        showRestTimerSheet = true
                    } label: {
                        Label("Rest Timer", systemImage: "timer")
                    }
                    
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
            .font(.system(.body, design: .rounded))
            .foregroundColor(.secondary)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            
            // Rest Timer Status
            Button {
                showRestTimerSheet = true
            } label: {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("Rest Timer: OFF")
                        .foregroundColor(.blue)
                }
            }
            .transition(.scale.combined(with: .opacity))
            
            // Sets Section
            VStack(spacing: 0) {
                // Sets Header
                HStack {
                    Text("SET")
                        .frame(width: 40, alignment: .leading)
                    Text("PREVIOUS")
                        .frame(width: 80, alignment: .leading)
                    Text("LBS")
                        .frame(width: 80)
                    Text("REPS")
                        .frame(width: 60)
                    Spacer()
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                
                // Sets List
                ForEach(exercise.sets.indices, id: \.self) { setIndex in
                    SetRow(
                        set: $workoutViewModel.exercises[exerciseIndex].sets[setIndex],
                        setNumber: setIndex + 1,
                        previousSet: exercise.previousWorkoutSets?.indices.contains(setIndex) == true ? exercise.previousWorkoutSets?[setIndex] : nil,
                        onDelete: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                workoutViewModel.removeSet(from: exerciseIndex, at: setIndex)
                            }
                        },
                        onDuplicate: {
                            let set = exercise.sets[setIndex]
                            var newSet = ExerciseSet(id: UUID().uuidString)
                            newSet.weight = set.weight
                            newSet.reps = set.reps
                            newSet.type = set.type
                            newSet.restInterval = set.restInterval
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                workoutViewModel.exercises[exerciseIndex].sets.insert(newSet, at: setIndex + 1)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    
                    if setIndex < exercise.sets.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
            
            // Add Set Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    workoutViewModel.addSet(to: exerciseIndex)
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Set")
                }
                .font(.system(.body, design: .rounded))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .sheet(isPresented: $showRestTimerSheet) {
            RestTimerSetupView(
                isPresented: $showRestTimerSheet,
                exerciseName: exercise.name,
                setNumber: exercise.sets.count,
                onStart: { duration in
                    isRestTimerActive = true
                    workoutViewModel.startRestTimer(
                        seconds: duration,
                        exerciseName: exercise.name,
                        setNumber: exercise.sets.count
                    )
                }
            )
        }
    }
}

struct SetRow: View {
    @Binding var set: ExerciseSet
    let setNumber: Int
    let previousSet: ExerciseSet?
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    
    var body: some View {
        HStack {
            Text("\(setNumber)")
                .frame(width: 40, alignment: .leading)
                .foregroundColor(.secondary)
            
            if let previous = previousSet {
                Button {
                    weightText = "\(Int(previous.weight))"
                    repsText = "\(previous.reps)"
                    set.weight = previous.weight
                    set.reps = previous.reps
                } label: {
                    Text("\(Int(previous.weight))×\(previous.reps)")
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
            }
            
            HStack(spacing: 2) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isWeightFocused)
                    .onChange(of: weightText) { newValue in
                        if let weight = Double(newValue) {
                            set.weight = weight
                        }
                    }
                    .frame(width: 50)
                
                Text("lbs")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($isRepsFocused)
                .onChange(of: repsText) { newValue in
                    if let reps = Int(newValue) {
                        set.reps = reps
                    }
                }
                .frame(width: 60)
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    set.isCompleted.toggle()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(set.isCompleted ? .green : .gray.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }
        .onAppear {
            weightText = set.weight > 0 ? "\(Int(set.weight))" : ""
            repsText = set.reps > 0 ? "\(set.reps)" : ""
        }
    }
}

#Preview {
    WorkoutView()
} 

