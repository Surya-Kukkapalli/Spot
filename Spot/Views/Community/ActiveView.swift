import SwiftUI

struct ActiveView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var showingCreateChallenge = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Group Challenges section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Group Challenges")
                        .font(.title2)
                        .bold()
                    
                    if viewModel.activeChallenges.isEmpty {
                        createChallengePrompt
                    } else {
//                        ForEach(viewModel.activeChallenges) { challenge in
//                            ChallengeCard(challenge: challenge, progress: viewModel.userProgress[challenge.id] ?? 0)
//                        }
                        // Note: for now keeping this for both cases until I design a new place to keep this
                        createChallengePrompt
                    }
                }
                .padding()
                
                // Completed Challenges section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Completed Challenges")
                        .font(.title2)
                        .bold()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("This Year")
                                .foregroundColor(.secondary)
                            Text("10")
                                .font(.title)
                                .bold()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("All Time")
                                .foregroundColor(.secondary)
                            Text("131")
                                .font(.title)
                                .bold()
                        }
                        
                        Spacer()
                        
                        Button("Find New Challenges") {
                            // Navigate to Challenges tab
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                .padding()
                
                // Active Challenges Grid
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.activeChallenges) { challenge in
                        NavigationLink(destination: ChallengeDetailsView(challenge: challenge, viewModel: viewModel)) {
                            ActiveChallengeRow(challenge: challenge, progress: viewModel.userProgress[challenge.id] ?? 0)
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateChallenge) {
            CreateChallengeView(viewModel: viewModel)
        }
    }
    
    private var createChallengePrompt: some View {
        VStack(spacing: 2) {
            Image("challenge_thumbnail")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
            
            Text("Now you can craft your own challenges. You set a goal, you make the rules and you decide who joins in.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Create a Group Challenge") {
                showingCreateChallenge = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Challenge icon/image
            if let badgeUrl = challenge.badgeImageUrl {
                AsyncImage(url: URL(string: badgeUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } placeholder: {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                }
            } else {
                Image(systemName: "trophy")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
            }
            
            Text(challenge.title)
                .font(.headline)
            
            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: progress, total: challenge.goal)
                .tint(.orange)
            
            HStack {
                Text("\(Int(progress)) / \(Int(challenge.goal)) \(challenge.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(challenge.progressPercentageForUser("")))%")
                    .font(.caption)
                    .bold()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ActiveChallengeRow: View {
    let challenge: Challenge
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            // Challenge icon/badge
            if let badgeUrl = challenge.badgeImageUrl {
                AsyncImage(url: URL(string: badgeUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } placeholder: {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            } else {
                Image(systemName: "trophy")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: challenge.type.iconName)
                    Text("\(Int(progress)) / \(Int(challenge.goal)) \(challenge.unit)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int((progress / challenge.goal) * 100))%")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Preview
struct ActiveView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveView(viewModel: CommunityViewModel())
    }
} 
