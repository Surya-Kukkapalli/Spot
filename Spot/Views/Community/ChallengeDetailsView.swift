import SwiftUI

struct ChallengeDetailsView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = "Overall"
    @State private var showingParticipants = false
    @State private var showingActivities = false
    @State private var showingComments = false
    @State private var animateContent = false
    
    private var formattedProgress: String {
        let progress = viewModel.userProgress[challenge.id] ?? 0
        if challenge.type == .time {
            return TimeFormatter.formatDuration(seconds: Int(progress))
        } else {
            return String(format: "%.1f", progress)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Badge and Title
                VStack(spacing: 16) {
                    if let badgeUrl = challenge.badgeImageUrl {
                        AsyncImage(url: URL(string: badgeUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        } placeholder: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                                .frame(width: 120, height: 120)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                    
                    Text(challenge.title)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        
                    // Challenge Status
                    if challenge.isExpired {
                        Text("Challenge Ended")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else if challenge.isCompleted {
                        Text("Challenge Completed!")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else if challenge.scope == .competitive && challenge.isCompletedByUser(viewModel.userId) {
                        Text("Goal Reached - Keep Pushing!")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                
                // Participants
                Button {
                    showingParticipants = true
                } label: {
                    ParticipantsPreview(challenge: challenge, viewModel: viewModel)
                }
                .sheet(isPresented: $showingParticipants) {
                    ParticipantsListView(challenge: challenge, viewModel: viewModel)
                }
                
                // Progress
                if viewModel.hasJoinedChallenge(challenge) {
                    ChallengeProgressView(challenge: challenge, viewModel: viewModel)
                        .padding(.horizontal)
                }
                
                // Challenge Info
                VStack(spacing: 16) {
                    // Date Range
                    HStack {
                        Image(systemName: "calendar")
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text("\(challenge.startDate.formatted(date: .long, time: .omitted)) to")
                            Text(challenge.endDate.formatted(date: .long, time: .omitted))
                        }
                        Spacer()
                        if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day {
                            Text("\(daysLeft) days left")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Challenge Type
                    HStack {
                        Image(systemName: challenge.type.iconName)
                            .frame(width: 24)
                        Text(challenge.type.displayName)
                        Spacer()
                    }
                    
                    // Challenge Scope
                    HStack {
                        Image(systemName: challenge.scope == .group ? "person.3" : "trophy")
                            .frame(width: 24)
                        Text(challenge.scope.displayName)
                        Text("•")
                        Text(challenge.scope.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Comments
                Button {
                    showingComments = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .frame(width: 24)
                        Text("Comments")
                        Spacer()
                        Text("\(challenge.comments.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .sheet(isPresented: $showingComments) {
                    ChallengeCommentsView(challenge: challenge, viewModel: viewModel)
                }
                
                // Your Effort
                VStack(alignment: .leading, spacing: 16) {
                    Text(challenge.scope == .group ? "Group Progress" : "Your Progress")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            let progress = challenge.scope == .group ? challenge.totalProgress : (viewModel.userProgress[challenge.id] ?? 0)
                            Text(formattedProgress)
                                .font(.title2)
                                .bold()
                            Text("of \(Int(challenge.goal)) \(challenge.unit)")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("See Your Activities") {
                            showingActivities = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .sheet(isPresented: $showingActivities) {
                    ChallengeActivitiesView(challenge: challenge, viewModel: viewModel)
                }
                
                // Leaderboard
                ChallengeLeaderboardView(challenge: challenge, selectedTab: $selectedTab)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateContent = true
            }
        }
        .task {
            await viewModel.loadParticipantProfiles(for: challenge)
        }
    }
}

// MARK: - Participants Preview
struct ParticipantsPreview: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: -8) {
                ForEach(challenge.participants.prefix(10), id: \.self) { userId in
                    if let profile = viewModel.participantProfiles[userId] {
                        AsyncImage(url: URL(string: profile.profileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                
                if challenge.participants.count > 10 {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .overlay(
                            Text("+\(challenge.participants.count - 10)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                }
            }
            
            Text("\(challenge.participants.count) participants")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Participants List View
struct ParticipantsListView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(challenge.participants, id: \.self) { userId in
                if let profile = viewModel.participantProfiles[userId] {
                    HStack {
                        AsyncImage(url: URL(string: profile.profileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 40, height: 40)
                        }
                        
                        Text(profile.username)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(Int(challenge.progressForUser(userId))) \(challenge.unit)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Challenge Activities View
struct ChallengeActivitiesView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var activities: [WorkoutSummary] = []
    
    var body: some View {
        NavigationView {
            List(activities) { activity in
                WorkoutSummaryRow(workout: activity)
            }
            .navigationTitle("Your Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                activities = await viewModel.getUserActivities(for: challenge)
            }
        }
    }
}

// MARK: - Challenge Comments View
struct ChallengeCommentsView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List(challenge.comments, id: \.id) { comment in
                    HStack(alignment: .top, spacing: 12) {
                        AsyncImage(url: URL(string: comment.userProfileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 40, height: 40)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.username)
                                .font(.headline)
                            Text(comment.content)
                            Text(comment.timestamp.formatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send") {
                        Task {
                            await viewModel.addComment(to: challenge, content: newComment)
                            newComment = ""
                        }
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Time Formatting Helper
enum TimeFormatter {
    static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Progress View
private struct ChallengeProgressView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let progress = challenge.scope == .group ? challenge.totalProgress : (viewModel.userProgress[challenge.id] ?? 0)
                Text("\(Int(progress)) / \(Int(challenge.goal)) \(challenge.unit)")
                    .font(.headline)
                Spacer()
                Text("\(Int((progress / challenge.goal) * 100))%")
                    .font(.headline)
            }
            
            ProgressView(value: challenge.scope == .group ? challenge.totalProgress : (viewModel.userProgress[challenge.id] ?? 0), total: challenge.goal)
                .tint(getProgressColor())
                
            if challenge.scope == .group {
                Text("Combined progress of all participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if challenge.isCompletedByUser(viewModel.userId) && !challenge.isExpired {
                Text("You've reached the goal! Keep pushing until the challenge ends.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func getProgressColor() -> Color {
        if challenge.isExpired {
            return .gray
        } else if challenge.isCompleted || 
                  (challenge.scope == .competitive && challenge.isCompletedByUser(viewModel.userId)) {
            return .green
        }
        return .orange
    }
}

// MARK: - Leaderboard View
private struct ChallengeLeaderboardView: View {
    let challenge: Challenge
    @Binding var selectedTab: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                LeaderboardTabButton(title: "Overall", selectedTab: $selectedTab)
                LeaderboardTabButton(title: "Following", selectedTab: $selectedTab)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Leaderboard header
            HStack {
                Text("ATHLETE")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(challenge.type == .time ? "TIME" : challenge.unit.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Participants list
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(selectedTab == "Overall" ? challenge.leaderboard : challenge.followingLeaderboard) { entry in
                    LeaderboardRow(entry: entry, challenge: challenge)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct LeaderboardRow: View {
    let entry: Challenge.LeaderboardEntry
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            AsyncImage(url: URL(string: entry.userProfileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
            }
            
            Text(entry.username)
                .font(.subheadline)
            
            Spacer()
            
            if challenge.type == .time {
                Text(TimeFormatter.formatDuration(seconds: Int(entry.progress)))
                    .font(.subheadline)
                    .monospacedDigit()
            } else {
                Text(String(format: "%.1f", entry.progress))
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
    }
}

private struct LeaderboardTabButton: View {
    let title: String
    @Binding var selectedTab: String
    
    var body: some View {
        Button(action: {
            selectedTab = title
        }) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedTab == title ? Color.orange : Color.clear)
                .foregroundColor(selectedTab == title ? .white : .primary)
        }
    }
}

// Preview
struct ChallengeDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChallengeDetailsView(
                challenge: Challenge(
                    title: "April Ten Days Active Challenge",
                    description: "Take your activities one day at a time! Get moving for at least 10 minutes a day 10 days this month and you'll earn the celebratory finisher's badge for this challenge.",
                    type: .time,
                    goal: 10,
                    unit: "days",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
                    creatorId: "testUser",
                    callToAction: "Can you set aside 10 minutes to be active for 10 days this month?"
                ),
                viewModel: CommunityViewModel()
            )
        }
    }
}

private struct WorkoutSummaryRow: View {
    let workout: WorkoutSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // User profile image
            AsyncImage(url: URL(string: workout.userProfileImageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Label("\(workout.duration)min", systemImage: "clock")
                    Label("\(workout.totalVolume)lbs", systemImage: "scalemass")
                    if let records = workout.personalRecords, !records.isEmpty {
                        Label("\(records.count) PR", systemImage: "trophy.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Date
            Text(workout.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
} 
