import SwiftUI
import FirebaseFirestore

@MainActor
class FollowingViewModel: ObservableObject {
    @Published var followedUsers: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchFollowing(for userId: String) async {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let user = try? userDoc.data(as: User.self),
                  !user.followingIds.isEmpty else {
                followedUsers = []
                isLoading = false
                return
            }
            
            let followedUsersSnapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: user.followingIds)
                .getDocuments()
            
            followedUsers = followedUsersSnapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
        } catch {
            self.error = error.localizedDescription
            print("Error fetching followed users: \(error)")
        }
        
        isLoading = false
    }
}

struct FollowingView: View {
    let userId: String
    @StateObject private var viewModel = FollowingViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.followedUsers.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Not following anyone yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.followedUsers) { user in
                        NavigationLink(destination: ProfileView(userId: user.id ?? "")) {
                            UserListItem(user: user)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Following")
        .task {
            await viewModel.fetchFollowing(for: userId)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

struct UserListItem: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                if let name = user.name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
} 
