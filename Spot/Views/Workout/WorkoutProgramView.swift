import SwiftUI

struct WorkoutProgramView: View {
    @StateObject private var viewModel = WorkoutProgramViewModel()
    @Environment(\.workoutViewModel) private var workoutViewModel
    @State private var selectedTab = 0
    @State private var showNewProgramSheet = false
    @State private var showCreateTemplate = false
    @State private var showExerciseSearch = false
    @State private var selectedTemplate: WorkoutTemplate?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Quick Start Section
                VStack(alignment: .leading) {
                    Text("Quick Start")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    Button(action: {
                        startEmptyWorkout()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Start an Empty Workout")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Programs Section Header
                VStack(alignment: .leading) {
                    HStack {
                        Text("Programs")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Button(action: {
                            showNewProgramSheet = true
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("New Program")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        
                        Button(action: {
                            // Handle explore action
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Explore")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Programs/Workouts Tabs
                    Picker("", selection: $selectedTab) {
                        Text("Programs").tag(0)
                        Text("Workouts").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Content based on selected tab
                ScrollView {
                    if selectedTab == 0 {
                        // Programs List
                        VStack(spacing: 16) {
                            ForEach(viewModel.programs) { program in
                                ProgramCard(program: program)
                            }
                        }
                    } else {
                        // Workouts/Templates List
                        VStack(spacing: 16) {
                            ForEach(viewModel.templates) { template in
                                NavigationLink(value: template) {
                                    WorkoutTemplateCard(template: template)
                                }
                            }
                            
                            Button(action: {
                                showCreateTemplate = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Make a new Workout")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: WorkoutTemplate.self) { template in
                if let viewModel = workoutViewModel {
                    WorkoutTemplateDetailView(template: template, mode: .start)
                        .environment(\.workoutViewModel, viewModel)
                }
            }
            .task {
                await viewModel.fetchUserPrograms()
                await viewModel.fetchUserTemplates()
            }
            .sheet(isPresented: $showNewProgramSheet) {
                NewProgramSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateTemplate) {
                CreateWorkoutTemplateView(viewModel: viewModel)
            }
            .sheet(isPresented: $showExerciseSearch) {
                NavigationStack {
                    ExerciseSearchView(workoutViewModel: workoutViewModel ?? WorkoutViewModel())
                }
            }
        }
    }
    
    private func startEmptyWorkout() {
        guard let viewModel = workoutViewModel else { return }
        viewModel.startNewWorkout(name: "")  // Empty name, will be set in SaveWorkoutView
        viewModel.isWorkoutInProgress = true
    }
}

// MARK: - Program Card
struct ProgramCard: View {
    let program: WorkoutProgram
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(program.name) (\(program.workoutCount))")
                            .font(.headline)
                        if let description = program.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .foregroundColor(.primary)
            
            if isExpanded {
                ForEach(program.workoutTemplates) { template in
                    NavigationLink(value: template) {
                        WorkoutTemplateCard(template: template)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Template Card
struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.name)
                .font(.headline)
            
            if let description = template.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Click to learn more")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Text("\(template.exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct NewProgramSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutProgramViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTemplates: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Select Workouts") {
                    ForEach(viewModel.templates) { template in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                if let description = template.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selectedTemplates.contains(template.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTemplates.contains(template.id) {
                                selectedTemplates.remove(template.id)
                            } else {
                                selectedTemplates.insert(template.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Program")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    Task {
                        let templates = viewModel.templates.filter { selectedTemplates.contains($0.id) }
                        try? await viewModel.createProgram(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            templates: templates
                        )
                        await viewModel.fetchUserPrograms() // Refresh programs
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || selectedTemplates.isEmpty)
            )
        }
    }
}

struct ExploreView: View {
    var body: some View {
        Text("Explore View - Coming Soon")
    }
}

#Preview {
    WorkoutProgramView()
} 
