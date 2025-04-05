import SwiftUI
import FirebaseAuth

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var selectedTab = 0
    @State private var showingCreateChallenge = false
    @State private var showingCreateTeam = false
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Search functionality
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                
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
                self.activeChallenges = active
                self.availableChallenges = available
                self.teams = userTeams
                
                print("DEBUG: Loaded \(active.count) active challenges")
                print("DEBUG: Loaded \(available.count) available challenges")
                print("DEBUG: Loaded \(userTeams.count) teams")
                
                // Update progress for active challenges
                for challenge in active {
                    self.userProgress[challenge.id] = challenge.progressForUser(userId)
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
}

// Preview
struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
    }
} 
