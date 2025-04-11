import SwiftUI
import PhotosUI

struct TeamSettingsView: View {
    let team: Team
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var selectedTags: Set<String>
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
    
    init(team: Team, viewModel: CommunityViewModel) {
        self.team = team
        self.viewModel = viewModel
        _name = State(initialValue: team.name)
        _description = State(initialValue: team.description)
        _isPrivate = State(initialValue: team.isPrivate)
        _selectedTags = State(initialValue: Set(team.tags))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Team photo
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let teamImage {
                                Image(uiImage: teamImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let imageUrl = team.imageUrl {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 100, height: 100)
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 100, height: 100)
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
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    
                    TextField("Team Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Privacy") {
                    Toggle("Private Team", isOn: $isPrivate)
                }
                
                Section("Tags") {
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
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                if team.creatorId == viewModel.userId {
                    Section {
                        Button("Delete Team", role: .destructive) {
                            // Implement delete team functionality
                        }
                    }
                }
            }
            .navigationTitle("Team Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
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
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else if selectedTags.count < 3 {
            selectedTags.insert(tag)
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                var imageUrl = team.imageUrl
                
                if let teamImage {
                    let storageService = StorageService()
                    imageUrl = try await storageService.uploadImage(teamImage, path: "teams/\(team.id ?? "")")
                }
                
                let updatedTeam = Team(
                    id: team.id,
                    name: name,
                    description: description,
                    creatorId: team.creatorId,
                    imageUrl: imageUrl,
                    members: team.members,
                    tags: Array(selectedTags),
                    isPrivate: isPrivate,
                    posts: team.posts,
                    admins: team.admins,
                    goals: team.goals
                )
                
                await viewModel.updateTeam(updatedTeam)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
} 