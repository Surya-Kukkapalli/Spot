import SwiftUI

struct TeamsView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var showingCreateTeam = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Create Team prompt
                createTeamPrompt
                
                if !viewModel.teams.isEmpty {
                    // User's teams
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Teams")
                            .font(.title2)
                            .bold()
                        
                        ForEach(viewModel.teams) { team in
                            TeamCard(team: team)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCreateTeam) {
            CreateTeamView(viewModel: viewModel)
        }
    }
    
    private var createTeamPrompt: some View {
        VStack(spacing: 16) {
            Text("Create your own Spot team")
                .font(.title2)
                .bold()
            
            Text("Connect with friends, share activities and stay motivated.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Create a Team") {
                showingCreateTeam = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct TeamCard: View {
    let team: Team
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Team header
            HStack(spacing: 12) {
                // Team image
                if let imageUrl = team.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 60, height: 60)
                    }
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 60)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "person.2")
                        Text("\(team.members.count) Members")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if team.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            // Team description
            Text(team.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Team goals
            if !team.goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Goals")
                        .font(.subheadline)
                        .bold()
                    
                    ForEach(team.goals.prefix(2)) { goal in
                        TeamGoalRow(goal: goal)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TeamGoalRow: View {
    let goal: Team.TeamGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(goal.progress / goal.target * 100))%")
                    .font(.caption)
                    .bold()
            }
            
            ProgressView(value: goal.progress, total: goal.target)
                .tint(.orange)
            
            HStack {
                Text("\(Int(goal.progress)) / \(Int(goal.target)) \(goal.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(goal.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Preview
struct TeamsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamsView(viewModel: CommunityViewModel())
    }
} 
