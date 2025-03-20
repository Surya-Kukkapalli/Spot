import SwiftUI
import FirebaseAuth

struct CreateWorkoutTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkoutProgramViewModel
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @State private var workoutTitle = ""
    @State private var description = ""
    @State private var showExerciseSearch = false
    @State private var selectedExercises: [Exercise] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TitleSection(workoutTitle: $workoutTitle, description: $description)
                
                if selectedExercises.isEmpty {
                    EmptyStateView(showExerciseSearch: $showExerciseSearch)
                } else {
                    ExerciseListView(
                        selectedExercises: $selectedExercises,
                        showExerciseSearch: $showExerciseSearch
                    )
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Create Workout Template")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveTemplate()
                }
                .disabled(workoutTitle.isEmpty || selectedExercises.isEmpty)
            )
            .sheet(isPresented: $showExerciseSearch) {
                NavigationStack {
                    ExerciseSearchView(workoutViewModel: workoutViewModel)
                        .onDisappear {
                            // Update selectedExercises with all exercises from workoutViewModel
                            selectedExercises = workoutViewModel.exercises
                            print("DEBUG: Updated selected exercises. Count: \(selectedExercises.count)")
                            print("DEBUG: Exercise names: \(selectedExercises.map { $0.name })")
                        }
                }
            }
        }
    }
    
    private func saveTemplate() {
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            print("DEBUG: Saving template with \(selectedExercises.count) exercises")
            print("DEBUG: Exercise names: \(selectedExercises.map { $0.name })")
            
            let workout = Workout(
                id: UUID().uuidString,
                userId: userId,
                name: workoutTitle,
                exercises: selectedExercises
            )
            
            try? await viewModel.createTemplate(from: workout, description: description, isPublic: false)
            await viewModel.fetchUserTemplates() // Refresh templates
            dismiss()
        }
    }
}

// MARK: - Subviews
private struct TitleSection: View {
    @Binding var workoutTitle: String
    @Binding var description: String
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Workout Template Title", text: $workoutTitle)
                .font(.title)
                .padding()
                .background(Color(.systemBackground))
            
            TextField("Description (optional)", text: $description)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color(.systemBackground))
        }
    }
}

private struct EmptyStateView: View {
    @Binding var showExerciseSearch: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Get started by adding an exercise to your workout template.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showExerciseSearch = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add exercise")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ExerciseListView: View {
    @Binding var selectedExercises: [Exercise]
    @Binding var showExerciseSearch: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(selectedExercises) { exercise in
                    WorkoutTemplateExerciseRow(exercise: exercise) {
                        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
                            selectedExercises.remove(at: index)
                        }
                    }
                }
                
                Button {
                    showExerciseSearch = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add exercise")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.blue)
                }
                .padding()
            }
        }
    }
}

struct WorkoutTemplateExerciseRow: View {
    let exercise: Exercise
    let onDelete: () -> Void
    
    var body: some View {
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
            
            // Analytics and More Options
            HStack(spacing: 8) {
                NavigationLink {
                    ExerciseDetailsView(exercise: ExerciseTemplate(
                        id: exercise.id,
                        name: exercise.name,
                        bodyPart: exercise.target,
                        equipment: exercise.equipment.description,
                        gifUrl: exercise.gifUrl,
                        target: exercise.target,
                        secondaryMuscles: exercise.secondaryMuscles,
                        instructions: exercise.notes?.components(separatedBy: "\n") ?? []
                    ))
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                }
                
                Menu {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    CreateWorkoutTemplateView(viewModel: WorkoutProgramViewModel())
} 
