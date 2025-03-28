import SwiftUI

struct SuggestedUsersSection: View {
    @ObservedObject var viewModel: UserDiscoveryViewModel
    @State private var showingAllUsers = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested Spotters")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                NavigationLink(destination: DiscoveryView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.suggestedUsers) { user in
                        SuggestedUserView(user: user) {
                            Task {
                                await viewModel.followUser(user.id ?? "")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .task {
            await viewModel.fetchSuggestedUsers()
        }
    }
}
