import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct OtherUserProfileView: View {
    let userId: String
    @StateObject private var viewModel: OtherUserProfileViewModel
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    init(userId: String) {
        print("DEBUG: Initializing OtherUserProfileView with userId: '\(userId)'")
        self.userId = userId
        _viewModel = StateObject(wrappedValue: OtherUserProfileViewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                if let user = viewModel.user {
                    VStack(spacing: 16) {
                        // Profile Image
                        if let imageUrl = user.profileImageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        
                        // Username and Bio
                        VStack(spacing: 8) {
                            Text(user.username)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let bio = user.bio {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Stats Row
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(viewModel.workoutSummaries.count)")
                                    .font(.headline)
                                Text("Workouts")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(user.followers)")
                                    .font(.headline)
                                Text("Followers")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(user.following)")
                                    .font(.headline)
                                Text("Following")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Follow Button
                        Button(action: {
                            Task {
                                await viewModel.toggleFollow()
                            }
                        }) {
                            Text(viewModel.isFollowing ? "Following" : "Follow")
                                .font(.headline)
                                .foregroundColor(viewModel.isFollowing ? .secondary : .white)
                                .frame(width: 200, height: 40)
                                .background(viewModel.isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                }
                
                // Progress Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Progress")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.progressItems) { item in
                                ProgressCard(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Tabs
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        VStack(spacing: 8) {
                            Text("Workouts")
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == 0 ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedTab = 1 }) {
                        VStack(spacing: 8) {
                            Text("Programs")
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == 1 ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                // Compare Button
                Button(action: {
                    // Compare functionality will be implemented later
                }) {
                    Text("Compare")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(22)
                        .padding(.horizontal)
                }
                
                // Recent Workouts
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Workouts")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(viewModel.workoutSummaries) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutSummaryCard(workout: workout)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("DEBUG: Starting to fetch data for userId: '\(userId)'")
            if userId.isEmpty {
                print("DEBUG: Empty user ID detected, dismissing view")
                dismiss()
                return
            }
            await viewModel.fetchUserData(userId: userId)
            await viewModel.fetchWorkouts(userId: userId)
        }
    }
}

// ViewModel for OtherUserProfileView
@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var workoutSummaries: [WorkoutSummary] = []
    @Published var isFollowing = false
    @Published var progressItems: [ProgressItem] = []
    
    private let db = Firestore.firestore()
    
    func fetchUserData(userId: String) async {
        print("DEBUG: Fetching user data for ID: '\(userId)'")
        guard !userId.isEmpty else {
            print("DEBUG: Empty user ID in fetchUserData")
            return
        }
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            print("DEBUG: User document exists: \(userDoc.exists)")
            
            var user = try userDoc.data(as: User.self)
            user.id = userId  // Ensure the user ID is set from the document ID
            print("DEBUG: Successfully decoded user: \(user.username) with ID: \(userId)")
            
            // Check if current user is following this user
            if let currentUserId = Auth.auth().currentUser?.uid {
                let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
                let currentUser = try currentUserDoc.data(as: User.self)
                isFollowing = currentUser.followingIds.contains(userId)
                print("DEBUG: Current user following status: \(isFollowing)")
            }
            
            await MainActor.run {
                self.user = user
            }
            await calculateProgress(for: user)
        } catch {
            print("DEBUG: Error fetching user data: \(error)")
        }
    }
    
    func fetchWorkouts(userId: String) async {
        print("DEBUG: Fetching workouts for user ID: '\(userId)'")
        guard !userId.isEmpty else {
            print("DEBUG: Empty user ID in fetchWorkouts")
            return
        }
        
        do {
            let snapshot = try await db.collection("workoutSummaries")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) workouts")
            
            await MainActor.run {
                self.workoutSummaries = snapshot.documents.compactMap { try? $0.data(as: WorkoutSummary.self) }
            }
        } catch {
            print("DEBUG: Error fetching workouts: \(error)")
        }
    }
    
    func toggleFollow() async {
        guard let userId = user?.id,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Missing user ID or current user ID for toggle follow")
            return
        }
        
        print("DEBUG: Toggling follow for user \(userId), current status: \(isFollowing)")
        
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
                
                print("DEBUG: Successfully unfollowed user")
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
                
                print("DEBUG: Successfully followed user")
            }
            
            isFollowing.toggle()
            if var user = user {
                user.followers += isFollowing ? 1 : -1
                self.user = user
            }
            
            // Post notification for profile update
            NotificationCenter.default.post(name: .userFollowStatusChanged, object: nil)
        } catch {
            print("DEBUG: Error toggling follow: \(error)")
        }
    }
    
    private func calculateProgress(for user: User) async {
        // Calculate progress items based on user's workout data
        // This is a placeholder - implement actual progress calculation
        self.progressItems = [
            ProgressItem(id: "1", title: "Total Workouts", value: "\(user.workoutsCompleted ?? 0)"),
            ProgressItem(id: "2", title: "Avg. Duration", value: formatDuration(user.averageWorkoutDuration ?? 0))
        ]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

struct ProgressItem: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct ProgressCard: View {
    let item: ProgressItem
    
    var body: some View {
        VStack(spacing: 8) {
            Text(item.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(item.value)
                .font(.headline)
        }
        .frame(width: 120, height: 80)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} 
