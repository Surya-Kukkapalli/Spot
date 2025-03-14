import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    HStack(alignment: .top, spacing: 20) {
                        PhotosPicker(selection: $selectedPhotoItem) {
                            if let url = authViewModel.currentUser?.profileImageUrl,
                               !url.isEmpty {
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.username ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let bio = authViewModel.currentUser?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(viewModel.workoutSummaries.count)")
                                        .font(.headline)
                                    Text("Workouts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(authViewModel.currentUser?.followers ?? 0)")
                                        .font(.headline)
                                    Text("Followers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(authViewModel.currentUser?.following ?? 0)")
                                        .font(.headline)
                                    Text("Following")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    // Chart Section
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Activity")
                                .font(.headline)
                            
                            Spacer()
                            
                            Picker("Metric", selection: $viewModel.selectedMetric) {
                                ForEach(ProfileViewModel.WorkoutMetric.allCases, id: \.self) { metric in
                                    Text(metric.rawValue).tag(metric)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        WorkoutChartView(
                            data: [], // We'll implement this data later
                            selectedMetric: $viewModel.selectedMetric
                        )
                    }
                    .padding()
                    
                    // Trophy Case & Exercises
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        NavigationLink(destination: Text("Trophy Case")) {
                            VStack {
                                Image(systemName: "trophy.fill")
                                    .font(.title)
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
                    }
                    .padding()
                    
                    // Workout History
                    VStack(alignment: .leading) {
                        Text("Workout History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.workoutSummaries) { summary in
                                    WorkoutSummaryCard(workout: summary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(authViewModel.currentUser?.username ?? "")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditProfile = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Settings") {
                            // Implement settings
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            showSignOutAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
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
                if let userId = authViewModel.currentUser?.id {
                    await viewModel.fetchUserWorkouts(for: userId)
                }
            }
            .onChange(of: selectedPhotoItem) { _ in
                Task {
                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let userId = authViewModel.currentUser?.id {
                        do {
                            let url = try await viewModel.uploadProfileImage(image, for: userId)
                            // Update user profile with new image URL
                            try await authViewModel.updateProfile(profileImageUrl: url)
                        } catch {
                            print("Error uploading profile image: \(error)")
                        }
                    }
                }
            }
        }
    }
} 