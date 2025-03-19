import SwiftUI
import FirebaseAuth

struct CreateWorkoutTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutProgramViewModel()
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
                            if let exercise = workoutViewModel.exercises.last {
                                if !selectedExercises.contains(where: { $0.id == exercise.id }) {
                                    selectedExercises.append(exercise)
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func saveTemplate() {
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            let workout = Workout(
                id: UUID().uuidString,
                userId: userId,
                name: workoutTitle,
                exercises: selectedExercises
            )
            
            try? await viewModel.createTemplate(from: workout, description: description, isPublic: false)
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
            
            // More Options Menu
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
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    CreateWorkoutTemplateView()
} 
