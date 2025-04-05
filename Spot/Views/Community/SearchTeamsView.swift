import SwiftUI

struct SearchTeamsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunityViewModel
    @State private var searchText = ""
    @State private var selectedFilter = TeamFilter.all
    
    private enum TeamFilter: String, CaseIterable {
        case all = "All"
        case justForFun = "Just for fun"
        case brand = "Brand or organization"
        case team = "Team"
        case employee = "Employee group"
        case coach = "Coach-led"
        case creator = "Creator"
    }
    
    private var filteredTeams: [Team] {
        let teams = viewModel.publicTeams.filter { team in
            if !searchText.isEmpty {
                return team.name.localizedCaseInsensitiveContains(searchText) ||
                       team.description.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        if selectedFilter == .all {
            return teams
        }
        
        return teams.filter { team in
            team.tags.contains(selectedFilter.rawValue)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TeamFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.orange : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Teams list
                List {
                    ForEach(filteredTeams) { team in
                        NavigationLink {
                            TeamDetailsView(team: team, viewModel: viewModel)
                        } label: {
                            TeamSearchRow(team: team, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .navigationTitle("Find Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadPublicTeams()
            }
        }
    }
}

struct TeamSearchRow: View {
    let team: Team
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
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
                
                Text(team.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label("\(team.members.count) Members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !team.tags.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(team.tags.first!)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if !viewModel.hasJoinedTeam(team) {
                Button {
                    viewModel.joinTeam(team)
                } label: {
                    Text("Join")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.orange, lineWidth: 1)
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Preview
struct SearchTeamsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchTeamsView(viewModel: CommunityViewModel())
    }
} 