import SwiftUI

class ExerciseSearchViewModel: ObservableObject {
    @Published var exercises: [ExerciseTemplate] = []
    @Published var filteredExercises: [ExerciseTemplate] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText: String = ""
    @Published var selectedFilter: FilterType = .all
    @Published var selectedExercises: Set<String> = [] // Track selected exercise IDs
    @Published var allExercises: [ExerciseTemplate] = []
    private var hasMoreExercises = true
    
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
            print("DEBUG: Loaded \(newExercises.count) exercises")
            exercises = newExercises
            filteredExercises = exercises
            hasMoreExercises = newExercises.count == 50 // pageSize
        } catch {
            print("DEBUG: Error loading exercises: \(error)")
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
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @StateObject private var viewModel = ExerciseSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $viewModel.searchText)
                .padding()
            
            // Filter buttons
            HStack(spacing: 16) {
                Button("All Equipment") {
                    viewModel.selectedFilter = .equipment
                }
                .buttonStyle(FilterButtonStyle(isSelected: viewModel.selectedFilter == .equipment))
                
                Button("All Muscles") {
                    viewModel.selectedFilter = .muscles
                }
                .buttonStyle(FilterButtonStyle(isSelected: viewModel.selectedFilter == .muscles))
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // Exercise list
            List {
                ForEach(viewModel.organizedExercises, id: \.section) { section in
                    Section(header: Text(section.section)) {
                        ForEach(section.exercises) { exercise in
                            ExerciseRowView(
                                exercise: exercise,
                                isSelected: viewModel.selectedExercises.contains(exercise.id),
                                onSelect: {
                                    print("DEBUG: Exercise tapped: \(exercise.name)")
                                    if viewModel.selectedExercises.contains(exercise.id) {
                                        print("DEBUG: Removing exercise from selection: \(exercise.name)")
                                        viewModel.selectedExercises.remove(exercise.id)
                                    } else {
                                        print("DEBUG: Adding exercise to selection: \(exercise.name)")
                                        viewModel.selectedExercises.insert(exercise.id)
                                    }
                                    print("DEBUG: Selected exercises count: \(viewModel.selectedExercises.count)")
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            
            // Add exercises button
            if !viewModel.selectedExercises.isEmpty {
                Button(action: addSelectedExercises) {
                    Text("Add \(viewModel.selectedExercises.count) exercise\(viewModel.selectedExercises.count == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("DEBUG: Loading exercises in ExerciseSearchView")
            await viewModel.loadExercises()
        }
    }
    
    private func addSelectedExercises() {
        print("DEBUG: Adding selected exercises. Count: \(viewModel.selectedExercises.count)")
        
        // Start a new workout if one isn't in progress
        if !workoutViewModel.isWorkoutInProgress {
            print("DEBUG: Starting new workout")
            workoutViewModel.startNewWorkout(name: "New Workout")
        }
        
        // Get all selected exercises from all possible sources
        let allExercises = viewModel.organizedExercises.flatMap { $0.exercises }
        let selectedTemplates = allExercises.filter { viewModel.selectedExercises.contains($0.id) }
        
        print("DEBUG: Selected templates: \(selectedTemplates.map { $0.name })")
        
        // Convert templates to exercises and add them
        for template in selectedTemplates {
            print("DEBUG: Converting template to exercise: \(template.name)")
            let exercise = Exercise(from: template)
            print("DEBUG: Created exercise with ID: \(exercise.id)")
            workoutViewModel.addExercise(exercise)
            ExerciseService.shared.addToRecent(template)
        }
        
        print("DEBUG: Total exercises in workout: \(workoutViewModel.exercises.count)")
        dismiss()
    }
}

struct ExerciseRowView: View {
    let exercise: ExerciseTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Selection indicator
            Rectangle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 4)
            
            // Main content
            Button(action: onSelect) {
                HStack(spacing: 1) {
                    AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 55, height: 50)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name.capitalized)
                            .font(.headline)
                        Text(exercise.target.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Analytics icon
            NavigationLink(destination: ExerciseDetailsView(exercise: exercise)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.gray)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .blue : .primary)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search exercise", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        ExerciseSearchView(workoutViewModel: WorkoutViewModel())
    }
} 
