import SwiftUI

struct CommentView: View {
    let workout: WorkoutSummary
    let onCommentAdded: (Int) -> Void
    @StateObject private var viewModel = CommentViewModel()
    @State private var newComment = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text(workout.workoutTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    AsyncImage(url: URL(string: workout.userProfileImageUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().foregroundColor(.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.username)
                            .font(.headline)
                        Text(workout.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Likes section
                HStack {
                    Text("\(workout.fistBumps) likes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -8) {
                            ForEach(viewModel.likedUsers) { user in
                                AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().foregroundColor(.gray.opacity(0.3))
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Comments
            ScrollView {
                if viewModel.comments.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Text("Spot \(workout.username) with a comment!")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment, onLikeTapped: {
                                Task {
                                    if let userId = authViewModel.currentUser?.id {
                                        await viewModel.toggleCommentLike(
                                            commentId: comment.id ?? "",
                                            userId: userId
                                        )
                                    }
                                }
                            })
                        }
                    }
                    .padding()
                }
            }
            
            // Comment input
            HStack {
                TextField("Add a comment", text: $newComment)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    Task {
                        guard !newComment.isEmpty,
                              let userId = authViewModel.currentUser?.id,
                              let username = authViewModel.currentUser?.username else { return }
                        
                        let newCount = await viewModel.addComment(
                            to: workout.id ?? "",
                            userId: userId,
                            username: username,
                            text: newComment
                        )
                        onCommentAdded(newCount)
                        newComment = ""
                    }
                } label: {
                    Text("Send")
                        .fontWeight(.semibold)
                }
                .disabled(newComment.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchComments(for: workout.id ?? "")
            await viewModel.fetchLikedUsers(for: workout.id ?? "")
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    let onLikeTapped: () -> Void
    
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: comment.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.userProfileImageUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().foregroundColor(.gray.opacity(0.3))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• \(formattedTimestamp)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.text)
                    .font(.subheadline)
                
                Button {
                    onLikeTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: comment.likedByCurrentUser ?? false ? "heart.fill" : "heart")
                            .foregroundColor(comment.likedByCurrentUser ?? false ? .red : .gray)
                        if comment.likes > 0 {
                            Text("\(comment.likes)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
} 
