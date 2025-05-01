import SwiftUI

struct ChallengeDetailsView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    @State private var selectedTab = 0 // 0 for Overall, 1 for Following
    @State private var scrollOffset: CGFloat = 0
    
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
            VStack(spacing: 0) {
                ChallengeBannerView(challenge: challenge) // Handles the banner image and badge display
                ChallengeInfoView(challenge: challenge, viewModel: viewModel) // Displays the challenge title, description, and call-to-action
                ChallengeProgressView(challenge: challenge, viewModel: viewModel) // Shows the user's progress and total progress
                ChallengeRequirementsView(challenge: challenge) // Displays the challenge duration and requirements
                ChallengeOrganizerView(challenge: challenge) // Shows the organizer's information
                ChallengeLeaderboardView(challenge: challenge, selectedTab: $selectedTab) // Handles the leaderboard display
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Banner View
private struct ChallengeBannerView: View {
    let challenge: Challenge
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Banner image
            if let imageUrl = challenge.bannerImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    Color.gray
                        .frame(height: 200)
                }
            } else {
                Color.gray
                    .frame(height: 200)
            }
            
            // Badge overlay
            if let badgeUrl = challenge.badgeImageUrl {
                AsyncImage(url: URL(string: badgeUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .offset(y: 50)
                } placeholder: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .offset(y: 50)
                }
            }
        }
    }
}

// MARK: - Info View
private struct ChallengeInfoView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Color.clear.frame(height: 60)
            
            Text(challenge.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let callToAction = challenge.callToAction {
                Text(callToAction)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if !viewModel.hasJoinedChallenge(challenge) {
                Button(action: {
                    viewModel.joinChallenge(challenge)
                }) {
                    Text("Join Challenge")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Progress View
private struct ChallengeProgressView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        if viewModel.hasJoinedChallenge(challenge) {
            VStack(spacing: 8) {
                HStack {
                    let progress = viewModel.userProgress[challenge.id] ?? 0
                    Text("\(Int(progress)) / \(Int(challenge.goal)) \(challenge.unit)")
                        .font(.headline)
                    Spacer()
                    Text("\(Int((progress / challenge.goal) * 100))%")
                        .font(.headline)
                }
                
                ProgressView(value: viewModel.userProgress[challenge.id] ?? 0, total: challenge.goal)
                    .tint(.orange)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Requirements View
private struct ChallengeRequirementsView: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(spacing: 20) {
            // Time range
            HStack {
                Image(systemName: "calendar")
                    .frame(width: 30)
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
            
            // Challenge requirements
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .frame(width: 30)
                    Text("Requirements")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: challenge.type.iconName)
                    Text("\(Int(challenge.goal)) \(challenge.unit)")
                    Spacer()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 30)
                
                if !challenge.qualifyingMuscles.isEmpty {
                    Text("Qualifying Muscles:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 30)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(challenge.qualifyingMuscles, id: \.self) { muscle in
                            Text(muscle.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.leading, 30)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Organizer View
private struct ChallengeOrganizerView: View {
    let challenge: Challenge
    
    var body: some View {
        if let organizer = challenge.organizer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AsyncImage(url: URL(string: organizer.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        Color.gray
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(organizer.type.uppercased())
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(organizer.name)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if organizer.type == "CLUB" {
                        Button("Join Club") {
                            // Join club action
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Leaderboard View
private struct ChallengeLeaderboardView: View {
    let challenge: Challenge
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabButton(title: "Overall", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Following", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
            }
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
                ForEach(selectedTab == 0 ? challenge.leaderboard : challenge.followingLeaderboard) { entry in
                    ParticipantRow(entry: entry, challenge: challenge)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
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

struct ParticipantRow: View {
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
