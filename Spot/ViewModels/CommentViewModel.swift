import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct Comment: Identifiable, Codable {
    var id: String?
    let userId: String
    let username: String
    let userProfileImageUrl: String?
    let text: String
    let timestamp: Date
    let workoutId: String
    var likes: Int
    var likedByCurrentUser: Bool?
}

@MainActor
class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var likedUsers: [User] = []
    private let db = Firestore.firestore()
    
    func fetchComments(for workoutId: String) async {
        do {
            print("Fetching comments for workout: \(workoutId)")
            let snapshot = try await db.collection("workout_comments")
                .whereField("workoutId", isEqualTo: workoutId)
                .order(by: "timestamp", descending: false)
                .getDocuments()
            
            print("Found \(snapshot.documents.count) comments")
            let currentUserId = Auth.auth().currentUser?.uid
            
            let fetchedComments = try await withThrowingTaskGroup(of: Comment?.self) { group in
                for document in snapshot.documents {
                    group.addTask {
                        guard var comment = try? document.data(as: Comment.self) else {
                            print("Failed to decode comment from document")
                            return nil
                        }
                        comment.id = document.documentID  // Ensure ID is set
                        
                        // Check if current user has liked this comment
                        if let currentUserId = currentUserId {
                            let likeDoc = try? await self.db.collection("comment_likes")
                                .document("\(document.documentID)_\(currentUserId)")
                                .getDocument()
                            comment.likedByCurrentUser = likeDoc?.exists ?? false
                        }
                        
                        return comment
                    }
                }
                
                var comments: [Comment] = []
                for try await comment in group {
                    if let comment = comment {
                        comments.append(comment)
                    }
                }
                return comments.sorted { $0.timestamp < $1.timestamp }
            }
            
            await MainActor.run {
                self.comments = fetchedComments
                print("Updated comments count: \(self.comments.count)")
            }
        } catch {
            print("Error fetching comments: \(error)")
            await MainActor.run {
                self.comments = []
            }
        }
    }
    
    func addComment(to workoutId: String, userId: String, username: String, text: String) async -> Int {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let user = try userDoc.data(as: User.self)
            
            let comment = Comment(
                id: nil,
                userId: userId,
                username: username,
                userProfileImageUrl: user.profileImageUrl,
                text: text,
                timestamp: Date(),
                workoutId: workoutId,
                likes: 0,
                likedByCurrentUser: false
            )
            
            // Save the comment
            let docRef = try await db.collection("workout_comments").addDocument(from: comment)
            
            // Update comment count on workout
            try await updateCommentCount(for: workoutId, increment: true)
            
            // Get updated comment count
            let workoutDoc = try await db.collection("workoutSummaries").document(workoutId).getDocument()
            let newCount = workoutDoc.data()?["comments"] as? Int ?? 0
            
            // Update local state
            await MainActor.run {
                var commentWithId = comment
                commentWithId.id = docRef.documentID
                self.comments.append(commentWithId)
            }
            
            // Fetch all comments again to ensure consistency
            await fetchComments(for: workoutId)
            
            return newCount
        } catch {
            print("Error adding comment: \(error)")
            return self.comments.count
        }
    }
    
    func toggleCommentLike(commentId: String, userId: String) async {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }
        let comment = comments[index]
        
        let likeRef = db.collection("comment_likes").document("\(commentId)_\(userId)")
        let commentRef = db.collection("workout_comments").document(commentId)
        
        do {
            if comment.likedByCurrentUser ?? false {
                // Unlike
                try await likeRef.delete()
                try await commentRef.updateData([
                    "likes": FieldValue.increment(Int64(-1))
                ])
                
                await MainActor.run {
                    comments[index].likes -= 1
                    comments[index].likedByCurrentUser = false
                }
            } else {
                // Like
                try await likeRef.setData([
                    "userId": userId,
                    "timestamp": Timestamp()
                ])
                try await commentRef.updateData([
                    "likes": FieldValue.increment(Int64(1))
                ])
                
                await MainActor.run {
                    comments[index].likes += 1
                    comments[index].likedByCurrentUser = true
                }
            }
        } catch {
            print("Error toggling comment like: \(error)")
        }
    }
    
    func fetchLikedUsers(for workoutId: String) async {
        do {
            let snapshot = try await db.collection("workout_likes")
                .whereField("workoutId", isEqualTo: workoutId)
                .getDocuments()
            
            let userIds = snapshot.documents.map { $0.data()["userId"] as? String ?? "" }
            
            self.likedUsers = []
            for userId in userIds {
                if let userDoc = try? await db.collection("users").document(userId).getDocument(),
                   let user = try? userDoc.data(as: User.self) {
                    self.likedUsers.append(user)
                }
            }
        } catch {
            print("Error fetching liked users: \(error)")
        }
    }
    
    private func updateCommentCount(for workoutId: String, increment: Bool) async throws {
        let workoutRef = db.collection("workoutSummaries").document(workoutId)
        let change = increment ? 1 : -1
        try await workoutRef.updateData([
            "comments": FieldValue.increment(Int64(change))
        ])
    }
} 
