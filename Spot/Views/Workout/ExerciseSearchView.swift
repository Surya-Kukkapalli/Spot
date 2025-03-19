import SwiftUI

class ExerciseSearchViewModel: ObservableObject {
    @Published var exercises: [ExerciseTemplate] = []
    @Published var filteredExercises: [ExerciseTemplate] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText: String = ""
    @Published var selectedFilter: FilterType = .all
    private var hasMoreExercises = true
    private var allExercises: [ExerciseTemplate] = []
    
    enum FilterType {
        case all
        case equipment
        case muscles
    }
    
    var organizedExercises: [(section: String, exercises: [ExerciseTemplate])] {
        var sections: [(String, [ExerciseTemplate])] = []
        
        // Get exercises that match search
        let searchResults: [ExerciseTemplate]
        if searchText.isEmpty {
            searchResults = filteredExercises
        } else {
            let searchSource = !allExercises.isEmpty ? allExercises : filteredExercises
            searchResults = searchSource.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Recent section
        let recentExercises = ExerciseService.shared.getRecentExercises()
        let recentSearchResults = searchText.isEmpty ? recentExercises :
            recentExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        if !recentSearchResults.isEmpty {
            sections.append(("Recent Exercises", recentSearchResults))
        }
        
        // All Exercises section (excluding recent ones)
        let remainingExercises = searchResults.filter { exercise in
            !recentExercises.contains { $0.id == exercise.id }
        }.sorted { $0.name < $1.name }
        
        if !remainingExercises.isEmpty {
            sections.append(("All Exercises", remainingExercises))
        }
        
        return sections
    }
    
    @MainActor
    func loadAllExercisesIfNeeded() async {
        guard !searchText.isEmpty && allExercises.isEmpty else { return }
        
        isLoading = true
        do {
            allExercises = try await ExerciseService.shared.fetchAllExercises()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func reset() {
        exercises = []
        filteredExercises = []
        allExercises = []
        hasMoreExercises = true
        ExerciseService.shared.reset()
    }
    
    @MainActor
    func loadExercises() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let newExercises = try await ExerciseService.shared.fetchExercises()
            exercises = newExercises
            filteredExercises = exercises
            hasMoreExercises = newExercises.count == 50 // pageSize
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadMoreIfNeeded(currentExercise exercise: ExerciseTemplate) async {
        guard hasMoreExercises,
              !isLoading,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }),
              index >= exercises.count - 10 else { return }
        
        isLoading = true
        
        do {
            let newExercises = try await ExerciseService.shared.fetchExercises()
            exercises.append(contentsOf: newExercises)
            filterExercises()
            hasMoreExercises = newExercises.count == 50
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func filterExercises() {
        // Implement filtering based on equipment or muscles when those views are added
        filteredExercises = exercises
    }
}

struct ExerciseSearchView: View {
    @StateObject private var viewModel = ExerciseSearchViewModel()
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEquipmentFilter = false
    @State private var showMuscleFilter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Filter buttons
            filterButtons
            
            if viewModel.isLoading && viewModel.exercises.isEmpty {
                ProgressView("Loading exercises...")
                    .frame(maxHeight: .infinity)
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.organizedExercises, id: \.section) { section in
                        Section(header: Text(section.section)) {
                            ForEach(section.exercises) { exercise in
                                ExerciseRow(exercise: exercise) {
                                    ExerciseService.shared.addToRecent(exercise)
                                    let newExercise = Exercise(from: exercise)
                                    workoutViewModel.addExercise(newExercise)
                                    dismiss()
                                }
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(currentExercise: exercise)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    // To be implemented: Create custom exercise
                }
                .foregroundColor(.blue)
            }
        }
        .task {
            viewModel.reset()
            await viewModel.loadExercises()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search exercise", text: $viewModel.searchText)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding()
    }
    
    private var filterButtons: some View {
        HStack(spacing: 16) {
            Button(action: { showEquipmentFilter = true }) {
                Text("All Equipment")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Button(action: { showMuscleFilter = true }) {
                Text("All Muscles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Exercise Image
                AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                // Exercise Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name.capitalized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(exercise.target.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Analytics icon
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseSearchView(workoutViewModel: WorkoutViewModel())
    }
} 