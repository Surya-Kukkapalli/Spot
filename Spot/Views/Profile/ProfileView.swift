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
    
    init(userId: String? = nil) {
        self.userId = userId
    }
    
    var isCurrentUser: Bool {
        userId == nil || userId == authViewModel.currentUser?.id
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ProfileHeaderSection(
                        user: isCurrentUser ? authViewModel.currentUser : userViewModel.user,
                        selectedPhotoItem: $selectedPhotoItem,
                        onPhotoChange: handlePhotoChange,
                        isCurrentUser: isCurrentUser
                    )
                    
                    StatsGridSection(viewModel: viewModel)
                    
                    WorkoutChartSection(
                        viewModel: viewModel,
                        selectedMetric: $selectedMetric
                    )
                    
                    NavigationGridSection(userId: userId ?? authViewModel.currentUser?.id ?? "")

                    WorkoutHistorySection(viewModel: viewModel)
                }
            }
            .navigationTitle(isCurrentUser ? (authViewModel.currentUser?.username ?? "") : (userViewModel.user?.username ?? ""))
            .toolbar {
                if isCurrentUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    try? authViewModel.signOut()
                }
            }
            .task {
                let targetUserId = userId ?? authViewModel.currentUser?.id
                if let targetUserId = targetUserId {
                    await viewModel.fetchUserWorkouts(for: targetUserId)
                    if !isCurrentUser {
                        await userViewModel.fetchUser(userId: targetUserId)
                    }
                }
            }
            .refreshable {
                let targetUserId = userId ?? authViewModel.currentUser?.id
                if let targetUserId = targetUserId {
                    await viewModel.fetchUserWorkouts(for: targetUserId)
                    if !isCurrentUser {
                        await userViewModel.fetchUser(userId: targetUserId)
                    }
                }
            }
        }
    }
    
    // TODO: Implement photo feature for profiles later
    private func handlePhotoChange() async {
        print("will implement later")
//        if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
//           let image = UIImage(data: data),
//           let userId = authViewModel.currentUser?.id {
//            do {
//                let url = try await viewModel.uploadProfileImage(image, for: userId)
//                try await authViewModel.updateProfile(profileImageUrl: url)
//            } catch {
//                print("Error uploading profile image: \(error)")
//            }
//        }
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
            
            NavigationLink(destination: Text("Exercises")) {
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.title)
                    Text("Exercises")
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
