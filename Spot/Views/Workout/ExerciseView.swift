import SwiftUI

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [ExerciseTemplate] = []
    @Published var filteredExercises: [ExerciseTemplate] = []
    @Published var isLoading = false
    @Published var error: String?
    
    @MainActor
    func loadExercises() async {
        isLoading = true
        error = nil
        
        do {
            exercises = try await ExerciseService.shared.fetchExercises()
            filteredExercises = exercises
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func filterExercises(by bodyPart: String? = nil, equipment: String? = nil) {
        filteredExercises = exercises.filter { exercise in
            let matchesBodyPart = bodyPart == nil || exercise.bodyPart.lowercased() == bodyPart?.lowercased()
            let matchesEquipment = equipment == nil || exercise.equipment.lowercased() == equipment?.lowercased()
            return matchesBodyPart && matchesEquipment
        }
    }
    
    // Add a function to convert ExerciseTemplate to Exercise
    func createExercise(from template: ExerciseTemplate) -> Exercise {
        return Exercise(from: template)
    }
}

struct ExerciseTemplateRowView: View {
    let exercise: ExerciseTemplate
    
    var body: some View {
        HStack(spacing: 16) {
            // Exercise Image
            AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            // Exercise Details
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name.capitalized)
                    .font(.headline)
                Text(exercise.target.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ExerciseView: View {
    @StateObject private var viewModel = ExerciseViewModel()
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredExercises: [ExerciseTemplate] {
        if searchText.isEmpty {
            return viewModel.filteredExercises
        }
        return viewModel.filteredExercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading exercises...")
            } else if let error = viewModel.error {
                Text("Error: \(error)")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredExercises) { template in
                            ExerciseTemplateRowView(exercise: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let exercise = Exercise(from: template)
                                    workoutViewModel.addExercise(exercise)
                                    dismiss()
                                }
                            Divider()
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadExercises()
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseTemplate
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)
                
                Group {
                    Text("Target Muscle: \(exercise.target.capitalized)")
                        .font(.headline)
                    
                    Text("Equipment: \(exercise.equipment.capitalized)")
                        .font(.headline)
                    
                    if !exercise.secondaryMuscles.isEmpty {
                        Text("Secondary Muscles:")
                            .font(.headline)
                        Text(exercise.secondaryMuscles.map { $0.capitalized }.joined(separator: ", "))
                    }
                    
                    Text("Instructions:")
                        .font(.headline)
                    ForEach(exercise.instructions.indices, id: \.self) { index in
                        Text("\(index + 1). \(exercise.instructions[index])")
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(exercise.name.capitalized)
    }
}

#Preview {
    NavigationView {
        ExerciseView(workoutViewModel: WorkoutViewModel())
    }
}
