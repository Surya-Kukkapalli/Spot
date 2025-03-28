import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// Add notification name
extension Notification.Name {
    static let userFollowStatusChanged = Notification.Name("userFollowStatusChanged")
}

@MainActor
class UserDiscoveryViewModel: ObservableObject {
    @Published var suggestedUsers: [User] = []
    @Published var searchResults: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    
    private let db = Firestore.firestore()
    
    func fetchSuggestedUsers(limit: Int = 10) async {
        isLoading = true
        print("DEBUG: Starting to fetch suggested users...")
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                error = "User not logged in"
                print("DEBUG: No current user found")
                isLoading = false
                return
            }
            
            print("DEBUG: Current user ID: \(currentUserId)")
            
            // Get current user's following list
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            print("DEBUG: Current user document exists: \(userDoc.exists)")
            
            let currentUser = try userDoc.data(as: User.self)
            let followingIds = currentUser.followingIds
            print("DEBUG: Current user following \(followingIds.count) users")
            
            // Query for all users
            print("DEBUG: Querying users collection...")
            let snapshot = try await db.collection("users").getDocuments()
            print("DEBUG: Raw document count: \(snapshot.documents.count)")
            
            // Print all document IDs for debugging
            snapshot.documents.forEach { doc in
                print("DEBUG: Found document with ID: \(doc.documentID)")
                if let data = try? doc.data(as: User.self) {
                    print("DEBUG: Successfully decoded user: \(data.username)")
                } else {
                    print("DEBUG: Failed to decode document: \(doc.documentID)")
                    print("DEBUG: Raw data: \(doc.data())")
                }
            }
            
            // Filter out current user and already followed users
            var users = snapshot.documents.compactMap { document -> User? in
                do {
                    var user = try document.data(as: User.self)
                    user.id = document.documentID // Always set the document ID as the user ID
                    print("DEBUG: Processing user: \(user.username) with ID: \(user.id ?? "nil")")
                    return user.id != currentUserId ? user : nil
                } catch {
                    print("DEBUG: Error decoding user document \(document.documentID): \(error)")
                    return nil
                }
            }.filter { user in
                let notFollowed = !followingIds.contains(user.id ?? "")
                print("DEBUG: User \(user.username) - followed: \(!notFollowed)")
                return notFollowed
            }
            
            // Sort by number of followers
            users.sort { $0.followers > $1.followers }
            print("DEBUG: Sorted \(users.count) users by followers")
            
            // Take only the first 'limit' users
            users = Array(users.prefix(limit))
            print("DEBUG: Final suggested users count: \(users.count)")
            
            await MainActor.run {
                self.suggestedUsers = users
            }
        } catch {
            print("DEBUG: Error fetching users: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func searchUsers(query: String, limit: Int = 15) async {
        isLoading = true
        print("DEBUG: Searching users with query: \(query)")
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("DEBUG: No current user found for search")
                return
            }
            
            print("DEBUG: Current user ID for search: \(currentUserId)")
            
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            print("DEBUG: Current user document exists for search: \(userDoc.exists)")
            
            let currentUser = try userDoc.data(as: User.self)
            let followingIds = currentUser.followingIds
            print("DEBUG: Current user following \(followingIds.count) users")
            
            // Query for all users
            print("DEBUG: Querying users for search...")
            let snapshot = try await db.collection("users").getDocuments()
            print("DEBUG: Found \(snapshot.documents.count) total users for search")
            
            var users = snapshot.documents.compactMap { document -> User? in
                do {
                    var user = try document.data(as: User.self)
                    user.id = document.documentID
                    print("DEBUG: Successfully decoded search user: \(user.username) with ID: \(user.id ?? "nil")")
                    return user.id != currentUserId ? user : nil
                } catch {
                    print("DEBUG: Error decoding search user document: \(error)")
                    return nil
                }
            }
            
            // Filter users based on search query and following status
            users = users.filter { user in
                let matchesSearch = query.isEmpty || 
                    user.username.lowercased().contains(query.lowercased()) ||
                    (user.name?.lowercased().contains(query.lowercased()) ?? false)
                let notFollowed = !followingIds.contains(user.id ?? "")
                print("DEBUG: Search user \(user.username) - matches search: \(matchesSearch), not followed: \(notFollowed)")
                return matchesSearch && notFollowed
            }
            
            // Sort by relevance and limit results
            users.sort { $0.followers > $1.followers }
            users = Array(users.prefix(limit))
            print("DEBUG: Final search results count: \(users.count)")
            
            await MainActor.run {
                self.searchResults = users
            }
        } catch {
            print("DEBUG: Error searching users: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func followUser(_ userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        print("DEBUG: Following user \(userId)")
        
        do {
            // Update current user's following list
            try await db.collection("users").document(currentUserId).updateData([
                "followingIds": FieldValue.arrayUnion([userId]),
                "following": FieldValue.increment(Int64(1))
            ])
            
            // Update target user's followers list
            try await db.collection("users").document(userId).updateData([
                "followerIds": FieldValue.arrayUnion([currentUserId]),
                "followers": FieldValue.increment(Int64(1))
            ])
            
            print("DEBUG: Successfully followed user \(userId)")
            
            // Remove the followed user from both lists
            await MainActor.run {
                suggestedUsers.removeAll { $0.id == userId }
                searchResults.removeAll { $0.id == userId }
                
                // Post notification for profile update
                NotificationCenter.default.post(name: .userFollowStatusChanged, object: nil)
            }
        } catch {
            print("DEBUG: Error following user: \(error)")
            self.error = error.localizedDescription
        }
    }
} 
