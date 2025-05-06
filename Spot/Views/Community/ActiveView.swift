import SwiftUI

struct ActiveView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var showingCreateChallenge = false
    @State private var selectedChallenge: Challenge?
    
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
                        Button {
                            selectedChallenge = challenge
                        } label: {
                            ActiveChallengeRow(challenge: challenge, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(item: $selectedChallenge) { challenge in
            NavigationView {
                ChallengeDetailsView(challenge: challenge, viewModel: viewModel)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
    @ObservedObject var viewModel: CommunityViewModel
    
    private var progress: Double {
        switch challenge.scope {
        case .group:
            return challenge.totalProgress
        case .competitive:
            return viewModel.userProgress[challenge.id] ?? 0
        }
    }
    
    private var progressPercentage: Double {
        guard challenge.goal > 0 else { return 0 }
        return (progress / Double(challenge.goal)) * 100.0
    }
    
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
                    // if challenge.scope == .group {
                    //     Text("(Combined)")
                    //         .font(.caption)
                    //         .foregroundColor(.secondary)
                    // }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(progressPercentage))%")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .contentShape(Rectangle())
    }
}

// Custom Refreshable View
struct RefreshableView<Content: View>: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    let content: Content
    
    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 100
    
    init(
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    MovingView(offset: offset, isRefreshing: isRefreshing)
                        .frame(height: threshold)
                        .opacity(offset / threshold)
                    
                    VStack {
                        content
                    }
                    .offset(y: max(0, offset + (isRefreshing ? threshold : 0)))
                    .animation(.spring(), value: isRefreshing)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: OffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(OffsetPreferenceKey.self) { offset in
                self.offset = offset
                
                if offset > threshold && !isRefreshing {
                    isRefreshing = true
                    Task {
                        await onRefresh()
                    }
                }
            }
        }
    }
}

private struct MovingView: View {
    let offset: CGFloat
    let isRefreshing: Bool
    
    var body: some View {
        HStack {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.orange)
            } else {
                Image(systemName: "arrow.down")
                    .rotationEffect(.degrees(min(Double(offset) / 40.0, 180.0)))
            }
            Text(isRefreshing ? "Refreshing..." : "Pull to refresh")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(isRefreshing ? 1 : min(1, Double(offset) / 50.0))
    }
}

private struct OffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Preview
struct ActiveView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveView(viewModel: CommunityViewModel())
    }
}
