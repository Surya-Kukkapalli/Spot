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
    @Published var userProgress: [String: Double] = [:] // Challenge ID to progress mapping
    @Published var errorMessage: String?
    @Published var isLoading = false
    
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
            
            let (active, available, userTeams) = try await (activeChallengesTask, availableChallengesTask, teamsTask)
            
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
                    print("DEBUG: Progress for challenge \(challenge.title): \(challenge.progressForUser(userId))")
                }
            }
        } catch {
            print("DEBUG: Error loading data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func hasJoinedChallenge(_ challenge: Challenge) -> Bool {
        challenge.participants.contains(userId)
    }
    
    func joinChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await service.joinChallenge(challenge.id, userId: userId)
                await loadData() // Refresh data
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await service.createChallenge(challenge)
                await loadData() // Refresh data
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createTeam(_ team: Team) {
        Task {
            do {
                try await service.createTeam(team)
                await loadData() // Refresh data
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func joinTeam(_ team: Team) {
        Task {
            do {
                try await service.joinTeam(team.id, userId: userId)
                await loadData() // Refresh data
            } catch {
                errorMessage = error.localizedDescription
            }
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
    
    func updateTeamGoal(_ teamId: String, goalId: String, progress: Double) {
        Task {
            do {
                try await service.updateTeamGoal(teamId, goalId: goalId, progress: progress)
                await loadData() // Refresh data to get updated team goals
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
