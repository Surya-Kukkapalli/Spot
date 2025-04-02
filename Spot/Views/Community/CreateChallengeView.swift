import SwiftUI
import PhotosUI

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunityViewModel
    @State private var title = ""
    @State private var description = ""
    @State private var type = Challenge.ChallengeType.distance
    @State private var goal: Double = 0
    @State private var unit = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week default
    @State private var selectedBadgeItem: PhotosPickerItem?
    @State private var selectedBannerItem: PhotosPickerItem?
    @State private var badgeImage: UIImage?
    @State private var bannerImage: UIImage?
    @State private var callToAction = ""
    @State private var selectedMuscles: Set<String> = []
    @State private var showingMuscleSelector = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let units: [String: [String]] = [
        "distance": ["km", "mi"],
        "volume": ["kg", "lbs"],
        "duration": ["hours", "minutes"],
        "count": ["workouts", "exercises"]
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Challenge Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Call to Action (optional)", text: $callToAction)
                        .font(.subheadline)
                    
                    Picker("Type", selection: $type) {
                        ForEach(Challenge.ChallengeType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    HStack {
                        TextField("Goal", value: $goal, format: .number)
                            .keyboardType(.decimalPad)
                        
                        Picker("Unit", selection: $unit) {
                            ForEach(units[type.rawValue] ?? [], id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .onChange(of: type) { newType in
                            if let firstUnit = units[newType.rawValue]?.first {
                                unit = firstUnit
                            }
                        }
                    }
                    
                    Button(action: {
                        showingMuscleSelector = true
                    }) {
                        HStack {
                            Text("Qualifying Muscles")
                            Spacer()
                            Text(selectedMuscles.isEmpty ? "All" : "\(selectedMuscles.count) selected")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Duration") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: [.date])
                }
                
                Section("Images") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Banner Image (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        PhotosPicker(selection: $selectedBannerItem, matching: .images) {
                            if let bannerImage {
                                Image(uiImage: bannerImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Select Banner Image")
                                }
                            }
                        }
                        
                        Text("Badge Image (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        PhotosPicker(selection: $selectedBadgeItem, matching: .images) {
                            if let badgeImage {
                                Image(uiImage: badgeImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Select Badge Image")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(!isValid)
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
            .onChange(of: selectedBannerItem) { _ in
                Task {
                    if let data = try? await selectedBannerItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        bannerImage = image
                    }
                }
            }
            .sheet(isPresented: $showingMuscleSelector) {
                MuscleSelectionView(selectedMuscles: $selectedMuscles)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty &&
        !description.isEmpty &&
        goal > 0 &&
        !unit.isEmpty &&
        endDate > startDate
    }
    
    private func createChallenge() {
        Task {
            do {
                let storageService = StorageService()
                let challengeId = UUID().uuidString
                
                // Upload images if selected
                var badgeUrl: String?
                var bannerUrl: String?
                
                if let badgeImage {
                    badgeUrl = try await storageService.uploadChallengeImage(badgeImage, challengeId: challengeId + "_badge")
                }
                
                if let bannerImage {
                    bannerUrl = try await storageService.uploadChallengeImage(bannerImage, challengeId: challengeId + "_banner")
                }
                
                let challenge = Challenge(
                    id: challengeId,
                    title: title,
                    description: description,
                    type: type,
                    goal: goal,
                    unit: unit,
                    startDate: startDate,
                    endDate: endDate,
                    creatorId: viewModel.userId,
                    badgeImageUrl: badgeUrl,
                    bannerImageUrl: bannerUrl,
                    callToAction: callToAction.isEmpty ? nil : callToAction,
                    qualifyingMuscles: Array(selectedMuscles)
                )
                
                viewModel.createChallenge(challenge)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct MuscleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMuscles: Set<String>
    @State private var searchText = ""
    @State private var availableMuscles: [String] = []
    @State private var isLoading = false
    
    private var filteredMuscles: [String] {
        if searchText.isEmpty {
            return availableMuscles
        }
        return availableMuscles.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Section {
                        ForEach(filteredMuscles, id: \.self) { muscle in
                            Button(action: { toggleMuscle(muscle) }) {
                                HStack {
                                    Text(muscle.capitalized)
                                    Spacer()
                                    if selectedMuscles.contains(muscle) {
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
            .searchable(text: $searchText, prompt: "Search muscles")
            .navigationTitle("Select Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedMuscles.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadMuscles()
            }
        }
    }
    
    private func loadMuscles() async {
        isLoading = true
        do {
            let exercises = try await ExerciseService.shared.fetchAllExercises()
            var muscles = Set<String>()
            for exercise in exercises {
                muscles.insert(exercise.target)
                muscles.formUnion(exercise.secondaryMuscles)
            }
            availableMuscles = muscles.sorted()
        } catch {
            print("Error fetching exercises: \(error)")
        }
        isLoading = false
    }
    
    private func toggleMuscle(_ muscle: String) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
    }
}

// Preview
struct CreateChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        CreateChallengeView(viewModel: CommunityViewModel())
    }
} 