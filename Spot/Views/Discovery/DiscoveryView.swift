import SwiftUI

struct DiscoveryView: View {
    @StateObject private var viewModel = UserDiscoveryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search on Spot", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
            
            // Tab Selection
            HStack(spacing: 0) {
                TabButton(title: "Search", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: "Contacts", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
            }
            .padding(.horizontal)
            
            // Tab Content
            if selectedTab == 0 {
                SearchTabView(viewModel: viewModel, searchText: $searchText)
            } else {
                ContactsTabView()
            }
        }
        .navigationBarHidden(true)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SearchTabView: View {
    @ObservedObject var viewModel: UserDiscoveryViewModel
    @Binding var searchText: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Invite Friends Row
                HStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading) {
                        Text("Invite a friend")
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                
                Divider()
                
                // User List
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    ForEach(viewModel.searchResults) { user in
                        UserRow(user: user) {
                            Task {
                                await viewModel.followUser(user.id ?? "")
                            }
                        }
                        Divider()
                    }
                }
            }
        }
        .onChange(of: searchText) { newValue in
            Task {
                await viewModel.searchUsers(query: newValue)
            }
        }
        .task {
            await viewModel.searchUsers(query: "")
        }
    }
}

struct UserRow: View {
    let user: User
    let onFollow: () -> Void
    @State private var isFollowing = false
    
    var body: some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.id ?? "")) {
            HStack {
                // Profile Image
                if let imageUrl = user.profileImageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let name = user.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .overlay(alignment: .trailing) {
            // Follow Button
            Button(action: {
                isFollowing = true
                onFollow()
            }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .cornerRadius(16)
            }
            .disabled(isFollowing)
        }
        .padding()
        .background(Color.white)
    }
}

struct ContactsTabView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("See which of your contacts are on Spot.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Contact sync functionality will be implemented later
            }) {
                Text("Connect Contacts")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 60)
    }
} 