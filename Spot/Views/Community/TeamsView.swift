import SwiftUI

struct TeamsView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var showingCreateTeam = false
    @State private var showingSearch = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Create Team prompt
                if viewModel.teams.isEmpty {
                    createTeamPrompt
                }
                
                // User's teams
                if !viewModel.teams.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Teams")
                            .font(.title2)
                            .bold()
                        
                        ForEach(viewModel.teams) { team in
                            NavigationLink {
                                TeamDetailsView(team: team, viewModel: viewModel)
                            } label: {
                                TeamCard(team: team)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCreateTeam) {
            CreateTeamFlowView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSearch) {
            SearchTeamsView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }
    
    private var createTeamPrompt: some View {
        VStack(spacing: 16) {
            Image("team_thumbnail") // Add this image to your assets
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
            
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
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                    
                    HStack {
                        Label("\(team.members.count) Members", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if team.isPrivate {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !team.tags.isEmpty {
                        Text(team.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Team description
            Text(team.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Latest post preview if available
            if let latestPost = team.posts.first {
                Divider()
                
                HStack(spacing: 12) {
                    if let authorImageUrl = latestPost.authorImageUrl {
                        AsyncImage(url: URL(string: authorImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 32, height: 32)
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(latestPost.authorName)
                            .font(.subheadline)
                            .bold()
                        
                        Text(latestPost.content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
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

// Preview
struct TeamsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamsView(viewModel: CommunityViewModel())
    }
} 
