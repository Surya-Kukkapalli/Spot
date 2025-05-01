import SwiftUI
import PhotosUI

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunityViewModel
    @State private var currentStep = 0
    @State private var showingDiscardAlert = false
    @State private var isCreating = false
    @State private var error: Error?
    @State private var showingErrorAlert = false
    
    // Challenge data
    @State private var selectedType: Challenge.ChallengeType?
    @State private var goal: Double = 0
    @State private var unit = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var title = ""
    @State private var description = ""
    @State private var selectedBadgeItem: PhotosPickerItem?
    @State private var badgeImage: UIImage?
    
    private let steps = ["Type", "Metrics", "Duration", "Details"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                
                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        ChallengeTypeSelectionView(selectedType: $selectedType)
                    case 1:
                        ChallengeMetricsView(type: selectedType ?? .volume, goal: $goal, unit: $unit)
                    case 2:
                        ChallengeDurationView(startDate: $startDate, endDate: $endDate)
                    case 3:
                        ChallengeDetailsInputView(
                            title: $title,
                            description: $description,
                            selectedBadgeItem: $selectedBadgeItem,
                            badgeImage: $badgeImage
                        )
                    default:
                        EmptyView()
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            if gesture.translation.height > 50 {
                                showingDiscardAlert = true
                            }
                        }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(steps[currentStep])
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    } else {
                        Button("Cancel") {
                            showingDiscardAlert = true
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .disabled(!canProceedToNextStep)
                    } else {
                        Button(action: createChallenge) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.orange)
                            } else {
                                Text("Create")
                            }
                        }
                        .disabled(!canCreateChallenge || isCreating)
                    }
                }
            }
            .alert("Discard Challenge?", isPresented: $showingDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard this challenge?")
            }
            .alert("Error Creating Challenge", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "An unknown error occurred")
            }
            .disabled(isCreating)
        }
    }
    
    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 0:
            return selectedType != nil
        case 1:
            return goal > 0 && !unit.isEmpty
        case 2:
            return endDate > startDate
        default:
            return false
        }
    }
    
    private var canCreateChallenge: Bool {
        !title.isEmpty && !description.isEmpty
    }
    
    private func createChallenge() {
        isCreating = true
        
        Task {
            do {
                let storageService = StorageService()
                let challengeId = UUID().uuidString
                
                var badgeUrl: String?
                if let badgeImage {
                    badgeUrl = try await storageService.uploadChallengeImage(badgeImage, challengeId: challengeId + "_badge")
                }
                
                let challenge = Challenge(
                    id: challengeId,
                    title: title,
                    description: description,
                    type: selectedType ?? .volume,
                    goal: goal,
                    unit: unit,
                    startDate: startDate,
                    endDate: endDate,
                    creatorId: viewModel.userId,
                    badgeImageUrl: badgeUrl
                )
                
                try await viewModel.createChallengeAndJoin(challenge)
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showingErrorAlert = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Step Views

struct ChallengeTypeSelectionView: View {
    @Binding var selectedType: Challenge.ChallengeType?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Let's get started. Pick your challenge type.")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                ForEach(Challenge.ChallengeType.allCases, id: \.self) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(.headline)
                                
                                Text(descriptionFor(type))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private func descriptionFor(_ type: Challenge.ChallengeType) -> String {
        switch type {
        case .volume:
            return "Track total weight lifted across all exercises"
        case .time:
            return "Track total time spent working out"
        case .oneRepMax:
            return "Compete for the highest one rep max"
        case .personalRecord:
            return "Set new personal records in any exercise"
        }
    }
}

struct ChallengeMetricsView: View {
    let type: Challenge.ChallengeType
    @Binding var goal: Double
    @Binding var unit: String
    
    // Time specific state
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    private let volumePresets: [(name: String, value: Double, description: String)] = [
        ("Lift a Car 🚗", 4000, "A typical car weighs around 4,000 lbs"),
        ("Lift an Elephant 🐘", 13000, "An African elephant weighs about 13,000 lbs"),
        ("Lift the Heaviest Rock 🪨", 1320000, "The heaviest rock ever lifted was 1,320,000 lbs"),
        ("Lift the Eiffel Tower 🗼", 22400000, "The Eiffel Tower weighs about 22,400,000 lbs")
    ]
    
    private let timePresets: [(name: String, value: Int, description: String)] = [
        ("Workout for a Day ☀️", 24 * 60, "24 hours of combined workout time"),
        ("Workout for a Week 📅", 7 * 24 * 60, "168 hours of combined workout time"),
        ("Workout for a Month 📆", 30 * 24 * 60, "720 hours of combined workout time"),
        ("Workout for a Year 🗓", 365 * 24 * 60, "8,760 hours of combined workout time")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text(headerText)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Input section
                switch type {
                case .volume:
                    volumeInputSection
                case .time:
                    timeInputSection
                default:
                    EmptyView()
                }
                
                // Preset section
                switch type {
                case .volume:
                    volumePresetSection
                case .time:
                    timePresetSection
                // temporary section until we implement One Rep Max and PR goals
                case .oneRepMax:
                    tempPresetSection
                case .personalRecord:
                    tempPresetSection
                default:
                    EmptyView()
                }
            }
            .padding()
        }
        .onChange(of: hours) { _ in updateTimeGoal() }
        .onChange(of: minutes) { _ in updateTimeGoal() }
        .onAppear {
            setupInitialUnit()
        }
    }
    
    private var headerText: String {
        switch type {
        case .volume:
            return "Set a combined volume goal for all participants"
        case .time:
            return "Set a combined time goal for all participants"
        default:
            return ""
        }
    }
    
    private var volumeInputSection: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Goal", value: $goal, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Unit", selection: $unit) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            Text("Total weight to be lifted by all participants")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var timeInputSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                VStack {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Hours", value: $hours, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
                
                VStack {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Minutes", value: $minutes, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
            }
            
            Text("Total time to be accumulated by all participants")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var volumePresetSection: some View {
        VStack(spacing: 12) {
            Text("Or choose a preset goal")
                .font(.headline)
                .padding(.top)
            
            ForEach(volumePresets, id: \.name) { preset in
                Button {
                    goal = preset.value
                } label: {
                    presetButton(
                        name: preset.name,
                        value: "\(Int(preset.value)) \(unit)",
                        description: preset.description
                    )
                }
            }
        }
    }
    
    private var timePresetSection: some View {
        VStack(spacing: 12) {
            Text("Or choose a preset goal")
                .font(.headline)
                .padding(.top)
            
            ForEach(timePresets, id: \.name) { preset in
                Button {
                    let totalMinutes = preset.value
                    hours = totalMinutes / 60
                    minutes = totalMinutes % 60
                    updateTimeGoal()
                } label: {
                    presetButton(
                        name: preset.name,
                        value: formatTime(minutes: preset.value),
                        description: preset.description
                    )
                }
            }
        }
    }
    
    // temporary preset section until we implement One Rep Max and PR goals
    private var tempPresetSection: some View {
        VStack(spacing: 16) {
            Text("Goal setting feature coming soon!")
                .font(.headline)
                .padding(.top)
        }
    }
    
    
    private func presetButton(name: String, value: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.orange)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatTime(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours) hours"
        }
        return "\(hours)h \(mins)m"
    }
    
    private func updateTimeGoal() {
        goal = Double(hours * 60 + minutes)
        unit = "minutes"
    }
    
    private func setupInitialUnit() {
        switch type {
        case .volume:
            if unit.isEmpty {
                unit = "lbs"
            }
        case .time:
            unit = "minutes"
            if let existingMinutes = Int(exactly: goal) {
                hours = existingMinutes / 60
                minutes = existingMinutes % 60
            }
        default:
            break
        }
    }
}

struct ChallengeDurationView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose when to kick your challenge off!")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("And when the cut-off date will be.")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Start Date")
                            .font(.headline)
                        DatePicker("Start Date",
                                 selection: $startDate,
                                 displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("End Date")
                            .font(.headline)
                        DatePicker("End Date",
                                 selection: $endDate,
                                 in: startDate...,
                                 displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
}

struct ChallengeDetailsInputView: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedBadgeItem: PhotosPickerItem?
    @Binding var badgeImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Give your challenge a name.")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("But don't stress about it – you can edit it later.")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 24) {
                    TextField("Challenge Name", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badge Image (optional)")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedBadgeItem, matching: .images) {
                            if let badgeImage {
                                Image(uiImage: badgeImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Select Badge Image")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .onChange(of: selectedBadgeItem) { _ in
                            Task {
                                if let data = try? await selectedBadgeItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    badgeImage = image
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
}

// Preview
struct CreateChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        CreateChallengeView(viewModel: CommunityViewModel())
    }
} 
