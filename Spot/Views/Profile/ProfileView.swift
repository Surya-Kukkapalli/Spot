import SwiftUI
import PhotosUI

struct ProfileView: View {
    let userId: String?
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var userViewModel = UserViewModel()
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedMetric: ProfileViewModel.WorkoutMetric = .duration
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(userId: String? = nil) {
        self.userId = userId
    }
    
    var isCurrentUser: Bool {
        userId == nil || userId == authViewModel.currentUser?.id
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let displayUser = isCurrentUser ? authViewModel.currentUser : userViewModel.user {
                    VStack(spacing: 20) {
                        ProfileHeaderSection(
                            user: displayUser,
                            selectedPhotoItem: $selectedPhotoItem,
                            onPhotoChange: handlePhotoChange,
                            isCurrentUser: isCurrentUser
                        )
                        
                        // Profile Stats with Navigation
                        HStack(spacing: 40) {
                            NavigationLink(destination: WorkoutHistoryView(userId: displayUser.id ?? "")) {
                                VStack {
                                    Text("\(displayUser.workoutsCompleted ?? 0)")
                                        .font(.title2)
                                        .bold()
                                    Text("Workouts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            NavigationLink(destination: FollowersView(userId: displayUser.id ?? "")) {
                                VStack {
                                    Text("\(displayUser.followers)")
                                        .font(.title2)
                                        .bold()
                                    Text("Followers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            NavigationLink(destination: FollowingView(userId: displayUser.id ?? "")) {
                                VStack {
                                    Text("\(displayUser.following)")
                                        .font(.title2)
                                        .bold()
                                    Text("Following")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        WorkoutChartSection(
                            viewModel: viewModel,
                            selectedMetric: $selectedMetric
                        )
                        
                        NavigationGridSection(userId: displayUser.id ?? "")
                        
                        if !viewModel.workoutSummaries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Workouts")
                                    .font(.title3)
                                    .bold()
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.workoutSummaries.prefix(3)) { workout in
                                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                        WorkoutSummaryCard(workout: workout)
                                    }
                                }
                                
                                NavigationLink(destination: WorkoutHistoryView(userId: displayUser.id ?? "")) {
                                    Text("View All")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                } else {
                    ProgressView("Loading profile...")
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                signOutAlert
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        print("DEBUG: ProfileView.loadData() - Initial userId: '\(String(describing: userId))'")
        print("DEBUG: ProfileView.loadData() - Current user ID: '\(String(describing: authViewModel.currentUser?.id))'")
        print("DEBUG: ProfileView.loadData() - Is current user? \(isCurrentUser)")
        
        guard let targetUserId = userId ?? authViewModel.currentUser?.id,
              !targetUserId.isEmpty else {
            print("DEBUG: ProfileView.loadData() - Invalid user ID condition met")
            print("DEBUG: ProfileView.loadData() - userId: '\(String(describing: userId))'")
            print("DEBUG: ProfileView.loadData() - currentUser.id: '\(String(describing: authViewModel.currentUser?.id))'")
            errorMessage = "Unable to load profile: Invalid user ID"
            showError = true
            return
        }
        
        print("DEBUG: ProfileView.loadData() - Loading data for user ID: '\(targetUserId)'")
        
        do {
            if !isCurrentUser {
                print("DEBUG: ProfileView.loadData() - Fetching non-current user data")
                await userViewModel.fetchUser(userId: targetUserId)
            } else {
                print("DEBUG: ProfileView.loadData() - Using current user data")
            }
            await viewModel.fetchUserWorkouts(for: targetUserId)
        } catch {
            print("DEBUG: ProfileView.loadData() - Error: \(error)")
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private var navigationTitle: String {
        isCurrentUser ? (authViewModel.currentUser?.username ?? "") : (userViewModel.user?.username ?? "")
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isCurrentUser {
                Menu {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        showSignOutAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
    
    private var signOutAlert: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                try? authViewModel.signOut()
            }
        }
    }
    
    // TODO: Implement photo feature for profiles later
    private func handlePhotoChange() async {
        print("will implement later")
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    let user: User?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onPhotoChange: () async -> Void
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isCurrentUser {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    profileImage
                }
                .onChange(of: selectedPhotoItem) { _ in
                    Task {
                        await onPhotoChange()
                    }
                }
            } else {
                profileImage
            }
            
            Text(user?.username ?? "")
                .font(.title2)
                .bold()
            
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
    
    private var profileImage: some View {
        AsyncImage(url: URL(string: user?.profileImageUrl ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundColor(.gray)
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
    }
}

// MARK: - Stats Grid Section
struct StatsGridSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        HStack(spacing: 40) {
            VStack {
                Text("\(viewModel.workoutSummaries.count)")
                    .font(.title2)
                    .bold()
                Text("Workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(viewModel.getTotalVolume())")
                    .font(.title2)
                    .bold()
                Text("Total Volume")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(viewModel.getTotalPRs())")
                    .font(.title2)
                    .bold()
                Text("PRs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Workout Chart Section
struct WorkoutChartSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var selectedMetric: ProfileViewModel.WorkoutMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.title3)
                .bold()
                .padding(.horizontal)
            
            Picker("Metric", selection: $selectedMetric) {
                ForEach(ProfileViewModel.WorkoutMetric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            WorkoutChartView(
                data: viewModel.getChartData(),
                selectedMetric: $selectedMetric
            )
            .padding(.top, 8)
        }
    }
}

// MARK: - Navigation Grid Section
struct NavigationGridSection: View {
    let userId: String
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            NavigationLink {
                TrophyCaseView(userId: userId)
            } label: {
                VStack {
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    Text("Trophy Case")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            NavigationLink(destination: Text("Analytics Page")) {
                VStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                    Text("Analytics Page - Coming soon")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            NavigationLink {
                PublicWorkoutsView(userId: userId)
            } label: {
                VStack {
                    Image(systemName: "figure.run")
                        .font(.title)
                    Text("Workouts")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            NavigationLink {
                PublicProgramsView(userId: userId)
            } label: {
                VStack {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title)
                    Text("Programs")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Workout History Section
struct WorkoutHistorySection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Text("Workout History")
            //     .font(.headline)
            //     .padding()
            
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                if !viewModel.workoutSummaries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout History")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
                        
                        ForEach(viewModel.workoutSummaries) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutSummaryCard(workout: workout)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemGray6))
    }
}
