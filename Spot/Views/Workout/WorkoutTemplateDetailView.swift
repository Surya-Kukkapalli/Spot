import SwiftUI
import FirebaseFirestore

enum WorkoutTemplateDisplayMode {
    case start
    case copy
}

struct WorkoutTemplateDetailView: View {
    let template: WorkoutTemplate
    let mode: WorkoutTemplateDisplayMode
    @Environment(\.workoutViewModel) private var workoutViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var programViewModel = WorkoutProgramViewModel()
    @StateObject private var userViewModel = UserViewModel()
    @State private var showingActionAlert = false
    @State private var showCopiedAlert = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title and Author
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title)
                        .bold()
                    
                    HStack {
                        if let user = userViewModel.user {
                            AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().foregroundColor(.gray.opacity(0.3))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            
                            Text("Created by \(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Created by Unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Description if available
                if let description = template.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Action Button
                Button {
                    showingActionAlert = true
                } label: {
                    Text(mode == .start ? "Start Workout" : "Save Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Stats Section (placeholder for now)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("Reps")
                        Spacer()
                        Text("Duration")
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    
                    // Placeholder chart
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 150)
                        .overlay(
                            Text("No data yet")
                                .foregroundColor(.secondary)
                        )
                }
                .padding(.vertical)
                
                // Exercises Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Exercises")
                            .font(.title3)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ForEach(template.exercises) { exercise in
                        WorkoutTemplateExerciseDetailRow(exercise: exercise)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await userViewModel.fetchUser(userId: template.userId)
        }
        .alert(mode == .start ? "Start Workout" : "Save Workout", isPresented: $showingActionAlert) {
            Button("Cancel", role: .cancel) { }
            Button(mode == .start ? "Start" : "Save") {
                if mode == .start {
                    startWorkout()
                } else {
                    copyTemplate()
                }
            }
        } message: {
            Text(mode == .start ? "Are you ready to start this workout?" : "Do you want to save this workout template?")
        }
        .alert("Workout Template Saved!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can find it in the templates section when logging your next workout.")
        }
    }
    
    private func startWorkout() {
        guard let viewModel = workoutViewModel else {
            print("DEBUG: workoutViewModel is nil")
            return
        }
        
        print("DEBUG: Starting workout from template: \(template.name)")
        print("DEBUG: Template has \(template.exercises.count) exercises")
        
        // Start a new workout with the template name
        viewModel.startNewWorkout(name: template.name)
        
        // Create new Exercise instances with empty sets for logging
        let exercises = template.exercises.map { templateExercise in
            var exercise = Exercise(
                id: UUID().uuidString,
                name: templateExercise.name,
                sets: [],
                equipment: templateExercise.equipment,
                gifUrl: templateExercise.gifUrl,
                target: templateExercise.target,
                secondaryMuscles: templateExercise.secondaryMuscles,
                notes: templateExercise.notes
            )
            // Add a default empty set to start logging
            exercise.sets.append(ExerciseSet(id: UUID().uuidString))
            return exercise
        }
        
        print("DEBUG: Created \(exercises.count) new exercises for workout")
        
        // Add all exercises to the workout
        exercises.forEach { viewModel.addExercise($0) }
        print("DEBUG: Added exercises to workout. Total exercises: \(viewModel.exercises.count)")
        
        // Update the active workout with template info
        if var workout = viewModel.activeWorkout {
            workout.name = template.name
            workout.notes = template.description
            viewModel.activeWorkout = workout
            print("DEBUG: Updated active workout with template info")
        } else {
            print("DEBUG: Error: activeWorkout is nil after startNewWorkout")
        }
        
        // Start the workout
        viewModel.isWorkoutInProgress = true
        print("DEBUG: Set isWorkoutInProgress to true")
        
        // Force view update and dismiss
        DispatchQueue.main.async {
            dismiss()
            print("DEBUG: Dismissed template view")
        }
    }
    
    private func copyTemplate() {
        Task {
            if let userId = authViewModel.currentUser?.id {
                try? await programViewModel.createTemplate(
                    from: Workout(
                        id: UUID().uuidString,
                        userId: userId,
                        name: template.name,
                        exercises: template.exercises,
                        notes: template.description
                    ),
                    description: template.description,
                    isPublic: false
                )
                showCopiedAlert = true
            }
        }
    }
}

struct WorkoutTemplateExerciseDetailRow: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Exercise Image and Name
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    
                    Text(exercise.name.capitalized)
                        .font(.headline)
                    
                    Spacer()
                }
                
                // Analytics
                NavigationLink {
                    ExerciseDetailsView(exercise: ExerciseTemplate(
                        id: exercise.id,
                        name: exercise.name,
                        bodyPart: exercise.target,
                        equipment: exercise.equipment.description,
                        gifUrl: exercise.gifUrl,
                        target: exercise.target,
                        secondaryMuscles: exercise.secondaryMuscles,
                        instructions: []
                    ))
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                }
            }
            
            if let notes = exercise.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Exercise Stats
            HStack {
                Text("SET")
                    .frame(width: 40, alignment: .leading)
                Text("LBS")
                    .frame(width: 60)
                Text("REPS")
                    .frame(width: 60)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            ForEach(exercise.sets.indices, id: \.self) { index in
                let set = exercise.sets[index]
                HStack {
                    Text("\(index + 1)")
                        .frame(width: 40, alignment: .leading)
                    Text("-")
                        .frame(width: 60)
                    Text("-")
                        .frame(width: 60)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    private let db = Firestore.firestore()
    
    func fetchUser(userId: String) async {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            user = try snapshot.data(as: User.self)
        } catch {
            print("Error fetching user: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutTemplateDetailView(template: WorkoutTemplate(
            userId: "user123",
            name: "Sample Workout",
            description: "A sample workout template",
            exercises: []
        ), mode: .start)
    }
} 
