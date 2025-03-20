import SwiftUI

struct WorkoutTemplateDetailView: View {
    let template: WorkoutTemplate
    @Environment(\.workoutViewModel) private var workoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingStartWorkoutAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title and Author
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title)
                        .bold()
                    Text("Created by \(template.userId)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Description if available
                if let description = template.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Start Workout Button
                Button {
                    showingStartWorkoutAlert = true
                } label: {
                    Text("Start Workout")
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
                        Button("Edit Workout Template") {
                            // Handle edit workout template
                        }
                        .foregroundColor(.blue)
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
        .alert("Start Workout", isPresented: $showingStartWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Start") {
                startWorkout()
            }
        } message: {
            Text("Are you ready to start this workout?")
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

#Preview {
    NavigationStack {
        WorkoutTemplateDetailView(template: WorkoutTemplate(
            userId: "user123",
            name: "Sample Workout",
            description: "A sample workout template",
            exercises: []
        ))
    }
} 