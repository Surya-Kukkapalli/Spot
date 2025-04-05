import SwiftUI
import PhotosUI

struct CreateTeamFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunityViewModel
    @State private var currentStep = 0
    
    // Team details
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTags: Set<String> = []
    @State private var isPrivate = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var teamImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let availableTags = [
        "Just for fun",
        "Brand or organization",
        "Team",
        "Employee group",
        "Coach-led",
        "Creator"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress bar
                HStack(spacing: 0) {
                    ForEach(0..<3) { step in
                        Rectangle()
                            .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        if step < 2 {
                            Spacer()
                                .frame(width: 4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Step content
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 0:
                            teamTypeStep
                        case 1:
                            customizeTeamStep
                        case 2:
                            privacyStep
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep < 2 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .disabled(!canProceed)
                    } else {
                        Button("Create") {
                            createTeam()
                        }
                        .disabled(!canProceed)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var teamTypeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Which best describes your club?")
                .font(.title)
                .bold()
            
            Text("Pick up to 3 tags that fit best. Let others know what you're all about.")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        toggleTag(tag)
                    } label: {
                        HStack {
                            Text(tag)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var customizeTeamStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Customize your club")
                .font(.title)
                .bold()
            
            Text("Choose a club name, add a photo and write a description.")
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                // Team photo
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    if let teamImage {
                        Image(uiImage: teamImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(editButton, alignment: .bottomTrailing)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            }
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
                
                TextField("Club Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }
    
    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Private or public?")
                .font(.title)
                .bold()
            
            VStack(spacing: 16) {
                Button {
                    isPrivate = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public")
                                .font(.headline)
                            Text("Anyone on Strava can join your club and view recent activity and content.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Circle()
                            .strokeBorder(!isPrivate ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if !isPrivate {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 16, height: 16)
                                }
                            }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                Button {
                    isPrivate = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private")
                                .font(.headline)
                            Text("People must request permission to join your club. Only admins can approve new members.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Circle()
                            .strokeBorder(isPrivate ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if isPrivate {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 16, height: 16)
                                }
                            }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var editButton: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: "pencil")
                    .foregroundColor(.white)
            }
            .offset(x: 6, y: 6)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !selectedTags.isEmpty && selectedTags.count <= 3
        case 1:
            return !name.isEmpty && !description.isEmpty
        case 2:
            return true
        default:
            return false
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else if selectedTags.count < 3 {
            selectedTags.insert(tag)
        }
    }
    
    private func createTeam() {
        Task {
            do {
                let teamId = UUID().uuidString
                var imageUrl: String?
                
                if let teamImage {
                    let storageService = StorageService()
                    imageUrl = try await storageService.uploadImage(teamImage, path: "teams/\(teamId)")
                }
                
                let team = Team(
                    id: teamId,
                    name: name,
                    description: description,
                    creatorId: viewModel.userId,
                    imageUrl: imageUrl,
                    tags: Array(selectedTags),
                    isPrivate: isPrivate
                )
                
                viewModel.createTeam(team)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// Preview
struct CreateTeamFlowView_Previews: PreviewProvider {
    static var previews: some View {
        CreateTeamFlowView(viewModel: CommunityViewModel())
    }
} 