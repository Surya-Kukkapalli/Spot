import SwiftUI
import FirebaseAuth

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var selectedTab = 0
    @State private var showingCreateChallenge = false
    @State private var showingCreateTeam = false
    @State private var showingCompletionAlert = false
    @State private var completedChallenge: Challenge?
    @State private var completedTrophy: Trophy?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                Spacer()
                
                // Custom tab bar
                HStack(spacing: 0) {
                    TabButton(title: "Active", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Challenges", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Teams", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    ActiveView(viewModel: viewModel)
                        .tag(0)
                    
                    ChallengesView(viewModel: viewModel)
                        .tag(1)
                    
                    TeamsView(viewModel: viewModel)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            // Messages
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .alert("Challenge Completed! 🎉", isPresented: $showingCompletionAlert) {
                Button("View Trophy Case") {
                    // Navigate to trophy case
                }
                Button("OK", role: .cancel) { }
            } message: {
                if let challenge = completedChallenge {
                    if challenge.scope == .competitive,
                       let trophy = completedTrophy,
                       let rankStr = trophy.metadata["rank"],
                       let rank = Int(rankStr) {
                        Text("Congratulations! You've completed '\(challenge.title)' and placed \(formatRank(rank))!")
                    } else {
                        Text("Congratulations! You've completed '\(challenge.title)'!")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .challengeCompleted)) { notification in
                if let challenge = notification.userInfo?["challenge"] as? Challenge,
                   let trophy = notification.userInfo?["trophy"] as? Trophy {
                    completedChallenge = challenge
                    completedTrophy = trophy
                    showingCompletionAlert = true
                }
            }
        }
    }
    
    private func formatRank(_ rank: Int) -> String {
        switch rank {
        case 1: return "1st place"
        case 2: return "2nd place"
        case 3: return "3rd place"
        default: return "\(rank)th place"
        }
    }
}

// View Model
@MainActor
class CommunityViewModel: ObservableObject {
    @Published var activeChallenges: [Challenge] = []
    @Published var availableChallenges: [Challenge] = []
    @Published var teams: [Team] = []
    @Published var publicTeams: [Team] = []
    @Published var userProgress: [String: Double] = [:]
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var currentUserImage: UIImage?
    @Published var participantProfiles: [String: UserProfile] = [:]
    
    struct UserProfile: Identifiable {
        let id: String
        let username: String
        let profileImageUrl: String?
    }
    
    private let service = CommunityService()
    private let auth = Auth.auth()
    
    var userId: String {
        auth.currentUser?.uid ?? ""
    }
    
    func loadData() async {
        print("DEBUG: Starting to load community data")
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let activeChallengesTask = service.getActiveChallenges(for: userId)
            async let availableChallengesTask = service.getAvailableChallenges()
            async let teamsTask = service.getUserTeams(for: userId)
            async let userImageTask = loadUserImage()
            
            let (active, available, userTeams, _) = try await (
                activeChallengesTask,
                availableChallengesTask,
                teamsTask,
                userImageTask
            )
            
            await MainActor.run {
                // Filter active challenges
                self.activeChallenges = active.filter { $0.shouldShowInActiveView }
                
                // Filter available challenges
                self.availableChallenges = available.filter { $0.shouldShowInChallengesView }
                
                self.teams = userTeams
                
                print("DEBUG: Loaded \(active.count) active challenges")
                print("DEBUG: Loaded \(available.count) available challenges")
                print("DEBUG: Loaded \(userTeams.count) teams")
                
                // Update progress for active challenges
                for challenge in active {
                    self.userProgress[challenge.id] = challenge.progressForUser(userId)
                }
                
                // Check for expired competitive challenges that need trophies
                Task {
                    for challenge in active where challenge.scope == .competitive && challenge.isExpired {
                        do {
                            let challengeProgressService = ChallengeProgressService()
                            try await challengeProgressService.addChallengeToTrophyCase(challenge, userId: userId)
                        } catch {
                            print("Error awarding trophy for expired challenge: \(error)")
                        }
                    }
                }
            }
        } catch {
            print("DEBUG: Error loading data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func loadPublicTeams() async {
        do {
            let teams = try await service.getPublicTeams()
            await MainActor.run {
                self.publicTeams = teams
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadUserImage() async {
        do {
            if let imageUrl = auth.currentUser?.photoURL {
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.currentUserImage = image
                    }
                }
            }
        } catch {
            print("Error loading user image: \(error)")
        }
    }
    
    func hasJoinedTeam(_ team: Team) -> Bool {
        team.members.contains(userId)
    }
    
    func hasJoinedChallenge(_ challenge: Challenge) -> Bool {
        challenge.participants.contains(userId)
    }
    
    func joinChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await service.joinChallenge(challenge.id, userId: userId)
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await service.createChallenge(challenge)
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createChallengeAndJoin(_ challenge: Challenge) async throws {
        try await service.createChallenge(challenge)
        // Calculate initial progress for the creator
        try await service.joinChallenge(challenge.id, userId: userId)
        await loadData()
    }
    
    func createTeam(_ team: Team) {
        Task {
            do {
                try await service.createTeam(team)
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func joinTeam(_ team: Team) {
        Task {
            do {
                guard let teamId = team.id else {
                    errorMessage = "Invalid team ID"
                    return
                }
                try await service.joinTeam(teamId, userId: userId)
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createTeamPost(teamId: String?, content: String, image: UIImage?) async {
        guard let teamId = teamId else { return }
        
        do {
            var imageUrl: String?
            if let image {
                let storageService = StorageService()
                imageUrl = try await storageService.uploadImage(image, path: "team_posts/\(teamId)/\(UUID().uuidString)")
            }
            
            let post = TeamPost(
                content: content,
                authorId: userId,
                authorName: auth.currentUser?.displayName ?? "Unknown",
                authorImageUrl: auth.currentUser?.photoURL?.absoluteString,
                imageUrl: imageUrl,
                isAdmin: true // TODO: Check if user is admin
            )
            
            try await service.createTeamPost(teamId: teamId, post: post)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addTeamGoal(_ teamId: String?, goal: TeamGoal) async {
        guard let teamId = teamId else { return }
        do {
            try await service.addTeamGoal(teamId, goal: goal)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func removeTeamGoal(_ teamId: String?, goalId: String) async {
        guard let teamId = teamId else { return }
        do {
            try await service.removeTeamGoal(teamId, goalId: goalId)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateTeamGoal(_ teamId: String?, goalId: String, progress: Double) async {
        guard let teamId = teamId else { return }
        do {
            try await service.updateTeamGoal(teamId, goalId: goalId, progress: progress)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateChallengeProgress(_ challengeId: String, progress: Double) {
        Task {
            do {
                try await service.updateChallengeProgress(challengeId, userId: userId, progress: progress)
                userProgress[challengeId] = progress
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func leaveTeam(_ team: Team) async {
        guard let teamId = team.id else {
            errorMessage = "Invalid team ID"
            return
        }
        do {
            try await service.leaveTeam(teamId, userId: userId)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateTeam(_ team: Team) async {
        do {
            try await service.updateTeam(team)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadParticipantProfiles(for challenge: Challenge) async {
        do {
            let profiles = try await service.getUserProfiles(userIds: challenge.participants)
            await MainActor.run {
                for profile in profiles {
                    participantProfiles[profile.id] = UserProfile(
                        id: profile.id,
                        username: profile.username,
                        profileImageUrl: profile.profileImageUrl
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addComment(to challenge: Challenge, content: String) async {
        guard let user = auth.currentUser else { return }
        
        do {
            let comment = Challenge.Comment(
                id: UUID().uuidString,
                userId: user.uid,
                content: content,
                timestamp: Date(),
                userProfileImageUrl: user.photoURL?.absoluteString,
                username: user.displayName ?? "Unknown"
            )
            try await service.addComment(to: challenge.id, comment: comment)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func getUserActivities(for challenge: Challenge) async -> [WorkoutSummary] {
        do {
            return try await service.getUserWorkouts(
                userId: userId,
                startDate: challenge.startDate,
                endDate: challenge.endDate
            )
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}

// Preview
struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
    }
} 
