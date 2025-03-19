import SwiftUI

struct WorkoutTemplateDetailView: View {
    let template: WorkoutTemplate
    @StateObject private var viewModel = WorkoutViewModel()
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
        viewModel.startNewWorkout(name: template.name)
        viewModel.exercises = template.exercises
        viewModel.isWorkoutInProgress = true
    }
}

struct WorkoutTemplateExerciseDetailRow: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Exercise Image
                AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                // Exercise Name
                Text(exercise.name.capitalized)
                    .font(.headline)
                
                Spacer()
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