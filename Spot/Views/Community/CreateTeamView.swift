import SwiftUI
import PhotosUI

struct CreateTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunityViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var teamImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Initial goal states
    @State private var showingAddGoal = false
    @State private var goals: [Team.TeamGoal] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Team Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Toggle("Private Team", isOn: $isPrivate)
                }
                
                Section("Team Image") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let teamImage {
                            Image(uiImage: teamImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .clipShape(Circle())
                        } else {
                            HStack {
                                Image(systemName: "photo")
                                Text("Select Team Image")
                            }
                        }
                    }
                }
                
                Section("Team Goals") {
                    ForEach(goals) { goal in
                        TeamGoalListItem(goal: goal)
                    }
                    .onDelete { indexSet in
                        goals.remove(atOffsets: indexSet)
                    }
                    
                    Button {
                        showingAddGoal = true
                    } label: {
                        Label("Add Goal", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTeam()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedItem) { _ in
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        teamImage = image
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddTeamGoalView { goal in
                    goals.append(goal)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !description.isEmpty
    }
    
    private func createTeam() {
        Task {
            do {
                // Upload team image if selected
                var imageUrl: String?
                if let teamImage {
                    let storageService = StorageService()
                    let teamId = UUID().uuidString // Generate ID first
                    imageUrl = try await storageService.uploadTeamImage(teamImage, teamId: teamId)
                    
                    let team = Team(
                        id: teamId, // Use the same ID
                        name: name,
                        description: description,
                        creatorId: viewModel.userId,
                        imageUrl: imageUrl,
                        goals: goals,
                        isPrivate: isPrivate
                    )
                    
                    viewModel.createTeam(team)
                    dismiss()
                } else {
                    // Create team without image
                    let team = Team(
                        name: name,
                        description: description,
                        creatorId: viewModel.userId,
                        goals: goals,
                        isPrivate: isPrivate
                    )
                    
                    viewModel.createTeam(team)
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct TeamGoalListItem: View {
    let goal: Team.TeamGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goal.title)
                .font(.headline)
            
            Text(goal.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(Int(goal.target)) \(goal.unit)", systemImage: "target")
                Spacer()
                Text(goal.targetDate.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct AddTeamGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Team.TeamGoal) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var type = Team.TeamGoal.GoalType.collective
    @State private var target: Double = 0
    @State private var unit = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days default
    
    private let units = [
        "km", "mi", "kg", "lbs", "hours", "minutes",
        "workouts", "exercises", "sessions"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Picker("Type", selection: $type) {
                        Text("Collective").tag(Team.TeamGoal.GoalType.collective)
                        Text("Average").tag(Team.TeamGoal.GoalType.average)
                        Text("Individual").tag(Team.TeamGoal.GoalType.individual)
                    }
                    
                    HStack {
                        TextField("Target", value: $target, format: .number)
                            .keyboardType(.decimalPad)
                        
                        Picker("Unit", selection: $unit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                    }
                    
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: [.date])
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let goal = Team.TeamGoal(
                            title: title,
                            description: description,
                            targetDate: targetDate,
                            type: type,
                            target: target,
                            unit: unit
                        )
                        onAdd(goal)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty &&
        !description.isEmpty &&
        target > 0 &&
        !unit.isEmpty
    }
}

// Preview
struct CreateTeamView_Previews: PreviewProvider {
    static var previews: some View {
        CreateTeamView(viewModel: CommunityViewModel())
    }
} 