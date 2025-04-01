import SwiftUI
import FirebaseFirestore

@MainActor
class FollowersViewModel: ObservableObject {
    @Published var followers: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchFollowers(for userId: String) async {
        print("DEBUG: Fetching followers for user ID: '\(userId)'")
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            print("DEBUG: Empty user ID in fetchFollowers")
            return
        }
        
        isLoading = true
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            print("DEBUG: User document exists: \(userDoc.exists)")

            guard let user = try? userDoc.data(as: User.self),
                  !user.followerIds.isEmpty else {
                print("DEBUG: No follower IDs found")
                followers = []
                isLoading = false
                return
            }

            print("DEBUG: Found \(user.followerIds.count) following IDs")
            
            let followersSnapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: user.followerIds)
                .getDocuments()
            
            followers = followersSnapshot.documents.compactMap { document -> User? in
                do {
                    var user = try document.data(as: User.self)
                    user.id = document.documentID // Ensure ID is set
                    print("DEBUG: Successfully decoded follower: \(user.username) with ID: \(user.id ?? "nil")")
                    return user
                } catch {
                    print("DEBUG: Error decoding follower document: \(error)")
                    return nil
                }
            }
            
            print("DEBUG: Successfully loaded \(followers.count) followers")
        } catch {
            self.error = error.localizedDescription
            print("DEBUG: Error fetching followers: \(error)")
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
                        NavigationLink(destination: OtherUserProfileView(userId: user.id ?? "")) {
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
