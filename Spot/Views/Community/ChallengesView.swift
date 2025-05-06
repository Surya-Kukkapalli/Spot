import SwiftUI

struct ChallengesView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var selectedFilter = ChallengeFilter.all
    @State private var searchText = ""
    @State private var selectedChallenge: Challenge?
    
    enum ChallengeFilter: String, CaseIterable {
        case all = "All"
        case volume = "Volume"
        case time = "Time"
        case oneRepMax = "One Rep Max"
        case personalRecord = "PRs"
        case group = "Collaborative"
        case competitive = "Competitive"
        
        func matches(_ challenge: Challenge) -> Bool {
            switch self {
            case .all:
                return true
            case .volume:
                return challenge.type == .volume
            case .time:
                return challenge.type == .time
            case .oneRepMax:
                return challenge.type == .oneRepMax
            case .personalRecord:
                return challenge.type == .personalRecord
            case .group:
                return challenge.scope == .group
            case .competitive:
                return challenge.scope == .competitive
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                Spacer()

                // Filter buttons 
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ChallengeFilter.allCases, id: \.self) { filter in
                            FilterButton(title: filter.rawValue,
                                       isSelected: selectedFilter == filter) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Debug information
                if viewModel.availableChallenges.isEmpty {
                    Text("No available challenges found")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                // Featured Challenge
                if let featuredChallenge = viewModel.availableChallenges.first {
                    Button {
                        selectedChallenge = featuredChallenge
                    } label: {
                        FeaturedChallengeCard(challenge: featuredChallenge, viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                
                // Active Challenges section
                if !viewModel.availableChallenges.isEmpty {
                    Text("Active Challenges (\(filteredChallenges.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Challenge grid
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredChallenges) { challenge in
                            Button {
                                selectedChallenge = challenge
                            } label: {
                                ChallengeListItem(
                                    challenge: challenge,
                                    joinAction: { viewModel.joinChallenge(challenge) },
                                    viewModel: viewModel
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(item: $selectedChallenge) { challenge in
            NavigationView {
                ChallengeDetailsView(challenge: challenge, viewModel: viewModel)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            print("DEBUG: ChallengesView appeared")
            print("DEBUG: Available challenges count: \(viewModel.availableChallenges.count)")
            for challenge in viewModel.availableChallenges {
                print("DEBUG: Challenge: \(challenge.title) (ID: \(challenge.id))")
            }
        }
    }
    
    var filteredChallenges: [Challenge] {
        viewModel.availableChallenges.filter { selectedFilter.matches($0) }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct FeaturedChallengeCard: View {
    let challenge: Challenge
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Challenge image
            if let imageUrl = challenge.badgeImageUrl {
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
            
            VStack(alignment: .leading, spacing: 12) {
                Text(challenge.title)
                    .font(.title2)
                    .bold()
                
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("Goal: \(Int(challenge.goal)) \(challenge.unit)", systemImage: challenge.type.iconName)
                    Spacer()
                    Text("\(challenge.participants.count) participants")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button(action: {
                    viewModel.joinChallenge(challenge)
                }) {
                    Text(viewModel.hasJoinedChallenge(challenge) ? "Joined Challenge" : "Join Challenge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.hasJoinedChallenge(challenge) ? .gray : .orange)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ChallengeListItem: View {
    let challenge: Challenge
    let joinAction: () -> Void
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Challenge icon/badge
            if let badgeUrl = challenge.badgeImageUrl {
                AsyncImage(url: URL(string: badgeUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } placeholder: {
                    Image(systemName: "trophy")
                        .font(.title)
                        .foregroundColor(.orange)
                        .frame(width: 60, height: 60)
                }
            } else {
                Image(systemName: "trophy")
                    .font(.title)
                    .foregroundColor(.orange)
                    .frame(width: 60, height: 60)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.headline)
                
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label("\(Int(challenge.goal)) \(challenge.unit)", systemImage: challenge.type.iconName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(challenge.participants.count) joined")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: joinAction) {
                Text(viewModel.hasJoinedChallenge(challenge) ? "Joined" : "Join")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(viewModel.hasJoinedChallenge(challenge) ? .gray : .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Preview
struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView(viewModel: CommunityViewModel())
    }
} 
