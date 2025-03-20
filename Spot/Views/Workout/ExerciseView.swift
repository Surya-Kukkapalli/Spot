import SwiftUI

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [ExerciseTemplate] = []
    @Published var filteredExercises: [ExerciseTemplate] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedBodyPart: String?
    @Published var selectedEquipment: String?
    @Published var searchText: String = ""
    private var hasMoreExercises = true
    private var allExercises: [ExerciseTemplate] = [] // Store all exercises for search
    
    var bodyParts: [String] = []
    var equipmentTypes: [String] = []
    
    var organizedExercises: [(section: String, exercises: [ExerciseTemplate])] {
        var sections: [(String, [ExerciseTemplate])] = []
        
        // Get exercises that match search
        let searchResults: [ExerciseTemplate]
        if searchText.isEmpty {
            searchResults = filteredExercises
        } else {
            // Use allExercises for search if available, otherwise use current exercises
            let searchSource = !allExercises.isEmpty ? allExercises : filteredExercises
            searchResults = searchSource.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Recent section
        let recentExercises = ExerciseService.shared.getRecentExercises()
        let recentSearchResults = searchText.isEmpty ? recentExercises :
            recentExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        if !recentSearchResults.isEmpty {
            sections.append(("Recent", recentSearchResults))
        }
        
        // Alphabetical sections
        let filtered = searchResults.filter { exercise in
            !recentExercises.contains { $0.id == exercise.id }
        }
        
        // Separate alphabetical and numerical exercises
        let (alphabetical, numerical) = filtered.reduce(into: ([ExerciseTemplate](), [ExerciseTemplate]())) { result, exercise in
            if exercise.name.first?.isLetter == true {
                result.0.append(exercise)
            } else {
                result.1.append(exercise)
            }
        }
        
        // Group alphabetical exercises
        let grouped = Dictionary(grouping: alphabetical) { exercise in
            String(exercise.name.prefix(1).uppercased())
        }
        
        let alphabeticalSections = grouped.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
        
        sections.append(contentsOf: alphabeticalSections)
        
        // Add numerical exercises to Misc section
        if !numerical.isEmpty {
            sections.append(("Misc", numerical.sorted { $0.name < $1.name }))
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
        allExercises = [] // Reset all exercises
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
            filterExercises() // Reapply any current filters
            hasMoreExercises = newExercises.count == 50 // pageSize
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
    
    @MainActor
    func updateFilters() {
        filteredExercises = exercises.filter { exercise in
            let matchesBodyPart = selectedBodyPart == nil || 
                exercise.bodyPart.lowercased() == selectedBodyPart?.lowercased()
            let matchesEquipment = selectedEquipment == nil || 
                exercise.equipment.lowercased() == selectedEquipment?.lowercased()
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
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onSelect) {
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
            }
            .foregroundColor(.primary)
            
            // Analytics icon
            NavigationLink(destination: ExerciseDetailsView(exercise: exercise)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ExerciseView: View {
    @StateObject private var viewModel = ExerciseViewModel()
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFilters = false
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.exercises.isEmpty {
                ProgressView("Loading exercises...")
            } else if let error = viewModel.error {
                Text("Error: \(error)")
            } else {
                filterBar
                
                List {
                    ForEach(viewModel.organizedExercises, id: \.section) { section in
                        Section(header: Text(section.section)) {
                            ForEach(section.exercises) { template in
                                ExerciseTemplateRowView(exercise: template) {
                                    ExerciseService.shared.addToRecent(template)
                                    let exercise = Exercise(from: template)
                                    workoutViewModel.addExercise(exercise)
                                    dismiss()
                                }
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(currentExercise: template)
                                    }
                                }
                            }
                        }
                    }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFilters.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterView(
                selectedBodyPart: $viewModel.selectedBodyPart,
                selectedEquipment: $viewModel.selectedEquipment,
                bodyParts: viewModel.bodyParts,
                equipmentTypes: viewModel.equipmentTypes
            )
        }
        .onChange(of: viewModel.selectedBodyPart, initial: false) { _, _ in
            viewModel.updateFilters()
        }
        .onChange(of: viewModel.selectedEquipment, initial: false) { _, _ in
            viewModel.updateFilters()
        }
        .onChange(of: viewModel.searchText, initial: false) { _, newValue in
            if !newValue.isEmpty {
                Task {
                    await viewModel.loadAllExercisesIfNeeded()
                }
            }
        }
        .task {
            viewModel.reset()
            await viewModel.loadExercises()
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let bodyPart = viewModel.selectedBodyPart {
                    FilterChip(text: bodyPart) {
                        viewModel.selectedBodyPart = nil
                    }
                }
                
                if let equipment = viewModel.selectedEquipment {
                    FilterChip(text: equipment) {
                        viewModel.selectedEquipment = nil
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: viewModel.selectedBodyPart == nil && viewModel.selectedEquipment == nil ? 0 : 44)
    }
}

struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text.capitalized)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedBodyPart: String?
    @Binding var selectedEquipment: String?
    let bodyParts: [String]
    let equipmentTypes: [String]
    
    var body: some View {
        NavigationView {
            List {
                Section("Body Part") {
                    ForEach(bodyParts, id: \.self) { bodyPart in
                        Button(action: {
                            selectedBodyPart = bodyPart
                            dismiss()
                        }) {
                            HStack {
                                Text(bodyPart.capitalized)
                                Spacer()
                                if selectedBodyPart == bodyPart {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section("Equipment") {
                    ForEach(equipmentTypes, id: \.self) { equipment in
                        Button(action: {
                            selectedEquipment = equipment
                            dismiss()
                        }) {
                            HStack {
                                Text(equipment.capitalized)
                                Spacer()
                                if selectedEquipment == equipment {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
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
