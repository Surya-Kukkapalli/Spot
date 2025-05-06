import SwiftUI
import FirebaseFirestore

struct TrophyCaseView: View {
    let userId: String
    @StateObject private var viewModel = TrophyCaseViewModel()
    @State private var selectedFilter: TrophyFilter = .all
    @State private var selectedChallenge: Challenge?
    
    enum TrophyFilter {
        case all, personalRecords, challenges
    }
    
    var body: some View {
        ScrollView {
            if viewModel.personalRecords.isEmpty && viewModel.challengeTrophies.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No trophies yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Filter buttons
                    Picker("Trophy Filter", selection: $selectedFilter) {
                        Text("All").tag(TrophyFilter.all)
                        Text("Personal Records").tag(TrophyFilter.personalRecords)
                        Text("Challenges").tag(TrophyFilter.challenges)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Trophy grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        // Personal Records
                        if selectedFilter == .all || selectedFilter == .personalRecords {
                            ForEach(viewModel.personalRecords) { pr in
                                PersonalRecordCard(record: pr)
                            }
                        }
                        
                        // Challenge Trophies
                        if selectedFilter == .all || selectedFilter == .challenges {
                            ForEach(viewModel.challengeTrophies) { trophy in
                                ChallengeTrophyCard(trophy: trophy)
                                    .onTapGesture {
                                        selectedChallenge = trophy.challenge
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Trophy Case")
        .task {
            guard !userId.isEmpty else { return }
            await viewModel.loadTrophies(for: userId)
        }
        .sheet(item: $selectedChallenge) { challenge in
            NavigationView {
                ChallengeDetailsView(challenge: challenge, viewModel: viewModel.communityViewModel)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct PersonalRecordCard: View {
    let record: PersonalRecordDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Spacer()
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(record.exerciseName)
                .font(.headline)
                .lineLimit(2)
            
            Text("\(String(format: "%.1f", record.weight))lbs × \(record.reps)")
                .font(.subheadline)
            
            Text("1RM: \(String(format: "%.1f", record.oneRepMax))lbs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ChallengeTrophyCard: View {
    let trophy: ChallengeTrophyDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: trophy.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } placeholder: {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Text(trophy.dateEarned.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(trophy.title)
                .font(.headline)
                .lineLimit(2)
            
            if let rank = trophy.rank {
                HStack {
                    Image(systemName: getMedalSymbol(for: rank))
                        .foregroundColor(getMedalColor(for: rank))
                    Text(getRankText(for: rank))
                        .font(.subheadline)
                }
            }
            
            Text("\(trophy.goal)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func getMedalSymbol(for rank: Int) -> String {
        switch rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "checkmark.circle.fill"
        }
    }
    
    private func getMedalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .green
        }
    }
    
    private func getRankText(for rank: Int) -> String {
        switch rank {
        case 1: return "1st Place"
        case 2: return "2nd Place"
        case 3: return "3rd Place"
        default: return "Completed"
        }
    }
}

// View Model for Trophy Case
@MainActor
class TrophyCaseViewModel: ObservableObject {
    @Published var personalRecords: [PersonalRecordDisplay] = []
    @Published var challengeTrophies: [ChallengeTrophyDisplay] = []
    private let db = Firestore.firestore()
    let communityViewModel = CommunityViewModel()
    
    func loadTrophies(for userId: String) async {
        do {
            // Load personal records
            let prService = PersonalRecordService()
            let records = try await prService.getAllPRs(userId: userId)
            self.personalRecords = records
                .map { PersonalRecordDisplay(from: $0) }
                .sorted { $0.date > $1.date }
            
            // Load challenge trophies
            let snapshot = try await db.collection("trophies")
                .whereField("userId", isEqualTo: userId)
                .whereField("type", isEqualTo: Trophy.TrophyType.challenge.rawValue)
                .getDocuments()
            
            var trophies: [ChallengeTrophyDisplay] = []
            
            for doc in snapshot.documents {
                if let trophy = try? doc.data(as: Trophy.self) {
                    // Get challenge details
                    guard let challengeId = trophy.metadata["challengeId"],
                          let challengeDoc = try? await db.collection("challenges")
                            .document(challengeId)
                            .getDocument(),
                          let challenge = try? challengeDoc.data(as: Challenge.self) else {
                        continue
                    }
                    
                    // Calculate rank for competitive challenges
                    var rank: Int?
                    if challenge.scope == .competitive {
                        let sortedParticipants = challenge.completions.sorted { $0.value > $1.value }
                        if let userIndex = sortedParticipants.firstIndex(where: { $0.key == userId }) {
                            rank = userIndex + 1
                        }
                    }
                    
                    let displayTrophy = ChallengeTrophyDisplay(
                        id: trophy.id,
                        title: trophy.title,
                        description: trophy.description,
                        imageUrl: trophy.imageUrl,
                        dateEarned: trophy.dateEarned,
                        goal: trophy.metadata["goal"] ?? "",
                        rank: rank,
                        challenge: challenge
                    )
                    
                    trophies.append(displayTrophy)
                }
            }
            
            await MainActor.run {
                self.challengeTrophies = trophies.sorted { $0.dateEarned > $1.dateEarned }
            }
        } catch {
            print("Error loading trophies: \(error)")
        }
    }
}

// Display model for Challenge Trophies
struct ChallengeTrophyDisplay: Identifiable {
    let id: String
    let title: String
    let description: String
    let imageUrl: String
    let dateEarned: Date
    let goal: String
    let rank: Int?
    let challenge: Challenge
}

// Display model for Personal Records
struct PersonalRecordDisplay: Identifiable {
    let id: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let oneRepMax: Double
    let date: Date
    
    init(from record: PersonalRecord) {
        self.id = record.id
        self.exerciseName = record.exerciseName
        self.weight = record.weight
        self.reps = record.reps
        self.oneRepMax = record.oneRepMax
        self.date = record.date
    }
} 