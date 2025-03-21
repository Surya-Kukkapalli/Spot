import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FollowButtonViewModel: ObservableObject {
    @Published var isFollowing = false
    private let db = Firestore.firestore()
    
    func checkFollowStatus(for userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            if let user = try? userDoc.data(as: User.self) {
                await MainActor.run {
                    isFollowing = user.followingIds.contains(userId)
                }
            }
        } catch {
            print("Error checking follow status: \(error)")
        }
    }
    
    func toggleFollow(for userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            if isFollowing {
                // Unfollow
                try await db.collection("users").document(currentUserId).updateData([
                    "followingIds": FieldValue.arrayRemove([userId]),
                    "following": FieldValue.increment(Int64(-1))
                ])
                
                try await db.collection("users").document(userId).updateData([
                    "followerIds": FieldValue.arrayRemove([currentUserId]),
                    "followers": FieldValue.increment(Int64(-1))
                ])
            } else {
                // Follow
                try await db.collection("users").document(currentUserId).updateData([
                    "followingIds": FieldValue.arrayUnion([userId]),
                    "following": FieldValue.increment(Int64(1))
                ])
                
                try await db.collection("users").document(userId).updateData([
                    "followerIds": FieldValue.arrayUnion([currentUserId]),
                    "followers": FieldValue.increment(Int64(1))
                ])
            }
            
            await MainActor.run {
                isFollowing.toggle()
            }
        } catch {
            print("Error toggling follow status: \(error)")
        }
    }
}

struct FollowButton: View {
    let userId: String
    @StateObject private var viewModel = FollowButtonViewModel()
    
    var body: some View {
        Button {
            Task {
                await viewModel.toggleFollow(for: userId)
            }
        } label: {
            Text(viewModel.isFollowing ? "Following" : "Follow")
                .font(.subheadline)
                .bold()
                .foregroundColor(viewModel.isFollowing ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewModel.isFollowing ? Color(.systemGray6) : Color.blue)
                .cornerRadius(8)
        }
        .task {
            await viewModel.checkFollowStatus(for: userId)
        }
    }
}

#Preview {
    FollowButton(userId: "testUserId")
} 