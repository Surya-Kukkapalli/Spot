import SwiftUI
import PhotosUI

struct TeamDetailsView: View {
    let team: Team
    @ObservedObject var viewModel: CommunityViewModel
    @State private var newPost = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingTeamSettings = false
    @State private var showingLeaveConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    private var isTeamAdmin: Bool {
        team.isAdmin(viewModel.userId)
    }
    
    private var isTeamCreator: Bool {
        team.creatorId == viewModel.userId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Team header
                VStack(spacing: 16) {
                    // Team image
                    if let imageUrl = team.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 120, height: 120)
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                    }
                    
                    Text(team.name)
                        .font(.title)
                        .bold()
                    
                    HStack(spacing: 24) {
                        Label("\(team.members.count) Members", systemImage: "person.2")
                        if team.isPrivate {
                            Label("Invite-Only", systemImage: "lock.fill")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    if !team.tags.isEmpty {
                        Text(team.tags.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(team.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                
                // Action buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        actionButton(icon: "person.badge.plus", text: "Invite")
                        actionButton(icon: "pencil", text: "Edit Club Details")
                        actionButton(icon: "info.circle", text: "Overview")
                        actionButton(icon: "chart.bar", text: "Activities")
                        actionButton(icon: "chart.line.uptrend.xyaxis", text: "Stats")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // New post composer
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        if let currentUserImage = viewModel.currentUserImage {
                            Image(uiImage: currentUserImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 40, height: 40)
                        }
                        
                        TextField("Post something...", text: $newPost, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...5)
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    self.selectedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                    }
                    
                    if !newPost.isEmpty || selectedImage != nil {
                        Button("Post") {
                            submitPost()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                .padding()
                
                // Posts
                LazyVStack(spacing: 0) {
                    ForEach(team.posts) { post in
                        PostView(post: post)
                            .padding()
                        
                        Divider()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isTeamAdmin {
                        Button {
                            showingTeamSettings = true
                        } label: {
                            Label("Team Settings", systemImage: "gear")
                        }
                        
                        Divider()
                    }
                    
                    if !isTeamCreator {  // Creator can't leave their own team
                        Button(role: .destructive) {
                            showingLeaveConfirmation = true
                        } label: {
                            Label("Leave Team", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingTeamSettings) {
            TeamSettingsView(team: team, viewModel: viewModel)
        }
        .alert("Leave Team", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.leaveTeam(team)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to leave this team? You'll need to be invited back to rejoin.")
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    private func actionButton(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.gray)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 80)
    }
    
    private func submitPost() {
        Task {
            guard let teamId = team.id else { return }
            await viewModel.createTeamPost(
                teamId: teamId,
                content: newPost,
                image: selectedImage
            )
            newPost = ""
            selectedImage = nil
        }
    }
}

struct PostView: View {
    let post: TeamPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                if let authorImageUrl = post.authorImageUrl {
                    AsyncImage(url: URL(string: authorImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.headline)
                    
                    if post.isAdmin {
                        Text("ADMIN")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Text(post.createdAt.formatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Post content
            Text(post.content)
                .font(.body)
            
            if let imageUrl = post.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Interactions
            HStack(spacing: 24) {
                Button {
                    // Like action
                } label: {
                    Label("\(post.likes.count)", systemImage: post.likes.isEmpty ? "heart" : "heart.fill")
                        .foregroundColor(post.likes.isEmpty ? .gray : .red)
                }
                
                Button {
                    // Comment action
                } label: {
                    Label("\(post.comments.count) comment\(post.comments.count == 1 ? "" : "s")", 
                          systemImage: "bubble.left")
                        .foregroundColor(.gray)
                }
            }
            .font(.subheadline)
        }
    }
}

// Preview
struct TeamDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamDetailsView(
            team: Team(
                name: "Sample Team",
                description: "This is a sample team description",
                creatorId: "123",
                tags: ["Just for fun", "Team"],
                isPrivate: false
            ),
            viewModel: CommunityViewModel()
        )
    }
} 