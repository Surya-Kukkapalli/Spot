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
    @Published var selectedEquipment: Set<String> = []
    @Published var selectedMuscles: Set<String> = []
    @Published var showFilterSheet = false
    private var hasMoreExercises = true
    
    enum FilterType {
        case all
        case equipment
        case muscles
    }
    
    var availableEquipment: [String] {
        Set(allExercises.map { $0.equipment }).sorted()
    }
    
    var availableMuscles: [String] {
        var muscles = Set<String>()
        for exercise in allExercises {
            muscles.insert(exercise.target)
            muscles.formUnion(exercise.secondaryMuscles)
        }
        return muscles.sorted()
    }
    
    var organizedExercises: [(section: String, exercises: [ExerciseTemplate])] {
        var sections: [(String, [ExerciseTemplate])] = []
        
        // Use allExercises for search and filtering if available
        let sourceExercises = !allExercises.isEmpty ? allExercises : exercises
        
        // Get exercises that match search and filters
        let searchResults = sourceExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || 
                exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesEquipment = selectedEquipment.isEmpty || 
                selectedEquipment.contains(exercise.equipment)
            let matchesMuscles = selectedMuscles.isEmpty || 
                selectedMuscles.contains(exercise.target) ||
                !Set(exercise.secondaryMuscles).isDisjoint(with: selectedMuscles)
            return matchesSearch && matchesEquipment && matchesMuscles
        }
        
        // Recent section
        let recentExercises = ExerciseService.shared.getRecentExercises()
        let recentSearchResults = searchResults.filter { exercise in
            recentExercises.contains { $0.id == exercise.id }
        }
        
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
        // Always load all exercises for search and filters
        guard allExercises.isEmpty else { return }
        
        isLoading = true
        do {
            allExercises = try await ExerciseService.shared.fetchAllExercises()
            // Update available equipment and muscles based on all exercises
            filterExercises()
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
        filteredExercises = exercises.filter { exercise in
            let matchesEquipment = selectedEquipment.isEmpty || selectedEquipment.contains(exercise.equipment)
            let matchesMuscles = selectedMuscles.isEmpty || 
                selectedMuscles.contains(exercise.target) ||
                !Set(exercise.secondaryMuscles).isDisjoint(with: selectedMuscles)
            return matchesEquipment && matchesMuscles
        }
    }
    
    func toggleEquipment(_ equipment: String) {
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
        filterExercises()
    }
    
    func toggleMuscle(_ muscle: String) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
        filterExercises()
    }
}

struct FilterSheetView: View {
    @ObservedObject var viewModel: ExerciseSearchViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.selectedFilter == .equipment {
                    Section("Equipment") {
                        ForEach(viewModel.availableEquipment, id: \.self) { equipment in
                            Button(action: { viewModel.toggleEquipment(equipment) }) {
                                HStack {
                                    Text(equipment.capitalized)
                                    Spacer()
                                    if viewModel.selectedEquipment.contains(equipment) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                } else if viewModel.selectedFilter == .muscles {
                    Section("Muscles") {
                        ForEach(viewModel.availableMuscles, id: \.self) { muscle in
                            Button(action: { viewModel.toggleMuscle(muscle) }) {
                                HStack {
                                    Text(muscle.capitalized)
                                    Spacer()
                                    if viewModel.selectedMuscles.contains(muscle) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.selectedFilter == .equipment ? "Equipment" : "Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
                Button(action: {
                    viewModel.selectedFilter = .equipment
                    viewModel.showFilterSheet = true
                }) {
                    HStack {
                        Text("All Equipment")
                        if !viewModel.selectedEquipment.isEmpty {
                            Text("(\(viewModel.selectedEquipment.count))")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(FilterButtonStyle(isSelected: !viewModel.selectedEquipment.isEmpty))
                
                Button(action: {
                    viewModel.selectedFilter = .muscles
                    viewModel.showFilterSheet = true
                }) {
                    HStack {
                        Text("All Muscles")
                        if !viewModel.selectedMuscles.isEmpty {
                            Text("(\(viewModel.selectedMuscles.count))")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(FilterButtonStyle(isSelected: !viewModel.selectedMuscles.isEmpty))
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // Exercise list
            List {
                ForEach(viewModel.organizedExercises, id: \.section) { section in
                    Section(header: Text(section.section)
                        .foregroundColor(Color.gray.opacity(0.8))
                        .font(.system(size: 17))
                        .textCase(nil)
                        .padding(.bottom, 8)
                    ) {
                        ForEach(section.exercises) { exercise in
                            ExerciseRowView(
                                exercise: exercise,
                                isSelected: viewModel.selectedExercises.contains(exercise.id),
                                onSelect: {
                                    if viewModel.selectedExercises.contains(exercise.id) {
                                        viewModel.selectedExercises.remove(exercise.id)
                                    } else {
                                        viewModel.selectedExercises.insert(exercise.id)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.visible)
                            .listRowBackground(Color.clear)
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
            // Load all exercises at startup
            await viewModel.loadAllExercisesIfNeeded()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            // No need to reload since we have all exercises
            viewModel.filterExercises()
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            FilterSheetView(viewModel: viewModel)
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
        ZStack {
            // Background selection indicator
            if isSelected {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            HStack(spacing: 1) {
                // Blue selection bar
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 4)
                
                // Content area
                HStack(spacing: 10) {
                    // Exercise image
                    AsyncImage(url: URL(string: exercise.gifUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    
                    // Exercise details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name.capitalized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(exercise.target.capitalized)
                            .font(.subheadline)
                            .foregroundColor(Color.gray.opacity(0.8))
                    }
                    
                    Spacer()
                    Spacer()
                    
                }
            }
            
            Spacer()
            
            // Analytics Icon
            NavigationLink(destination: ExerciseDetailsView(exercise: exercise)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                    .opacity(0) // Hides the icon for now until I figure out how to use it to cover up the chevron ">" indicator
            }
            .buttonStyle(PlainButtonStyle())
            
            
            // Invisible button for selection covering everything except the analytics icon
            Button(action: onSelect) {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            // Adjust the frame to not cover the analytics icon
            .padding(.trailing, 60)
        }
        .frame(height: 89)
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
