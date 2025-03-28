import SwiftUI

struct SuggestedUserView: View {
    let user: User
    var onFollow: () -> Void
    @State private var isFollowing = false
    
    var body: some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.id ?? "")) {
            VStack(alignment: .center, spacing: 8) {
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
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                }
                
                // Username
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // Featured or connection info
                Text("Featured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .overlay(alignment: .bottom) {
            // Follow Button
            Button(action: {
                isFollowing = true
                onFollow()
            }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .frame(width: 100, height: 32)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .cornerRadius(16)
            }
            .disabled(isFollowing)
            .offset(y: 20)
        }
        .frame(width: 120)
        .padding(.vertical, 8)
        .padding(.bottom, 24)
    }
} 