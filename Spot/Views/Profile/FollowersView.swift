import SwiftUI
import FirebaseFirestore

@MainActor
class FollowersViewModel: ObservableObject {
    @Published var followers: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchFollowers(for userId: String) async {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let user = try? userDoc.data(as: User.self),
                  !user.followerIds.isEmpty else {
                followers = []
                isLoading = false
                return
            }
            
            let followersSnapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: user.followerIds)
                .getDocuments()
            
            followers = followersSnapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
        } catch {
            self.error = error.localizedDescription
            print("Error fetching followers: \(error)")
        }
        
        isLoading = false
    }
}

struct FollowersView: View {
    let userId: String
    @StateObject private var viewModel = FollowersViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.followers.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No followers yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.followers) { user in
                        NavigationLink(destination: ProfileView(userId: user.id ?? "")) {
                            UserListItem(user: user)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Followers")
        .task {
            await viewModel.fetchFollowers(for: userId)
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

#Preview {
    NavigationView {
        FollowersView(userId: "testUserId")
    }
} 
