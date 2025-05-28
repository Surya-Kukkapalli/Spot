import SwiftUI

struct WorkoutSummaryCard: View {
    let workout: WorkoutSummary
    @StateObject private var interactionViewModel = WorkoutInteractionViewModel()
    @State private var hasLiked = false
    @State private var fistBumpCount: Int
    @State private var commentCount: Int
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showComments = false
    @State private var showShareSheet = false
    @State private var showCopiedAlert = false
    @StateObject private var programViewModel = WorkoutProgramViewModel()
    @State private var profileImageUrl: String?
    
    init(workout: WorkoutSummary) {
        self.workout = workout
        _fistBumpCount = State(initialValue: workout.fistBumps)
        _commentCount = State(initialValue: workout.comments)
        _profileImageUrl = State(initialValue: workout.userProfileImageUrl)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack {
                NavigationLink(destination: {
                    if let currentUserId = authViewModel.currentUser?.id,
                       currentUserId == workout.userId {
                        ProfileView()
                    } else {
                        OtherUserProfileView(userId: workout.userId)
                    }
                }) {
                    AsyncImage(url: URL(string: profileImageUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().foregroundColor(.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    NavigationLink(destination: {
                        if let currentUserId = authViewModel.currentUser?.id,
                           currentUserId == workout.userId {
                            ProfileView()
                        } else {
                            OtherUserProfileView(userId: workout.userId)
                        }
                    }) {
                        Text(workout.username)
                            .font(.headline)
                    }
                    Text(workout.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: {
                        Task {
                            if let userId = authViewModel.currentUser?.id {
                                try? await programViewModel.createTemplate(
                                    from: Workout(
                                        id: UUID().uuidString,
                                        userId: userId,
                                        name: workout.workoutTitle,
                                        exercises: workout.exercises.map { exercise in
                                            Exercise(
                                                id: UUID().uuidString,
                                                name: exercise.exerciseName,
                                                sets: [],
                                                equipment: Equipment(),
                                                gifUrl: exercise.imageUrl,
                                                target: exercise.targetMuscle,
                                                secondaryMuscles: [],
                                                notes: nil
                                            )
                                        },
                                        notes: workout.workoutNotes
                                    ),
                                    description: workout.workoutNotes,
                                    isPublic: false
                                )
                                showCopiedAlert = true
                            }
                        }
                    }) {
                        Label("Save Workout", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Label("Share Workout", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            
            // Workout content
            VStack(alignment: .leading, spacing: 12) {
                // Workout title
                Text(workout.workoutTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Workout notes (if any)
                if let notes = workout.workoutNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.top, -1)
                }
                
                // PR Banner
                if let records = workout.personalRecords, !records.isEmpty,
                   let firstPR = records.values.first {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("\(workout.username) Hit a PR on \(firstPR.exerciseName)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(8)
                }
                
                // Stats row
                HStack(spacing: 16) {
                    Label("\(workout.duration)min", systemImage: "clock")
                    Label("\(workout.totalVolume)lbs", systemImage: "scalemass")
                    if let records = workout.personalRecords, !records.isEmpty {
                        Label("\(records.count) PR\(records.count == 1 ? "" : "s")", systemImage: "trophy.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Exercise section headers
                HStack {
                    Text("Exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Best Set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
                
                // Exercise list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(workout.exercises.prefix(3), id: \.exerciseName) { exercise in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: exercise.imageUrl)) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.exerciseName)
                                    .font(.subheadline)
                                Text("\(exercise.sets.count) sets · \(exercise.sets.reduce(0) { $0 + Int($1.weight * Double($1.reps)) })lbs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let bestSet = exercise.bestSet {
                                HStack(spacing: 4) {
                                    if let records = workout.personalRecords,
                                       records[exercise.exerciseName] != nil {
                                        Image(systemName: "trophy.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                    }
                                    Text(bestSet.displayString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if workout.exercises.count > 3 {
                        Text("+ \(workout.exercises.count - 3) more exercises")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Interaction buttons with even spacing
                HStack {
                    Spacer()
                    Button {
                        Task {
                            if let userId = authViewModel.currentUser?.id {
                                hasLiked.toggle()
                                fistBumpCount += hasLiked ? 1 : -1
                                try? await interactionViewModel.toggleLike(
                                    for: workout.id,
                                    userId: userId,
                                    isLiked: hasLiked
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: hasLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            Text("\(fistBumpCount)")
                        }
                    }
                    
                    Spacer()
                    Divider()
                        .frame(height: 20)
                    Spacer()
                    
                    Button {
                        showComments = true
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left")
                            Text("\(commentCount)")
                        }
                    }
                    .sheet(isPresented: $showComments) {
                        CommentView(workout: workout) { newCount in
                            commentCount = newCount
                        }
                    }
                    
                    Spacer()
                    Divider()
                        .frame(height: 20)
                    Spacer()
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            Task {
                                if let userId = authViewModel.currentUser?.id {
                                    try? await programViewModel.createTemplate(
                                        from: Workout(
                                            id: UUID().uuidString,
                                            userId: userId,
                                            name: workout.workoutTitle,
                                            exercises: workout.exercises.map { exercise in
                                                Exercise(
                                                    id: UUID().uuidString,
                                                    name: exercise.exerciseName,
                                                    sets: [],
                                                    equipment: Equipment(),
                                                    gifUrl: exercise.imageUrl,
                                                    target: exercise.targetMuscle,
                                                    secondaryMuscles: [],
                                                    notes: nil
                                                )
                                            },
                                            notes: workout.workoutNotes
                                        ),
                                        description: workout.workoutNotes,
                                        isPublic: false
                                    )
                                    showCopiedAlert = true
                                }
                            }
                        }) {
                            Label("Save Workout", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Label("Share Workout", systemImage: "square.and.arrow.up")
                        }
                    }
                    Spacer()
                }
                .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .task {
            if let userId = authViewModel.currentUser?.id {
                hasLiked = await interactionViewModel.checkIfLiked(
                    workoutId: workout.id,
                    userId: userId
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "https://spotapp.com/workout/\(workout.id)") {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Workout Template Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can find it in the templates section when logging your next workout.")
        }
        .onAppear {
            // Check if we need to update the profile image URL from the current user
            if workout.userId == authViewModel.currentUser?.id,
               let currentImageUrl = authViewModel.currentUser?.profileImageUrl {
                profileImageUrl = currentImageUrl
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("userProfileImageUpdated"))) { notification in
            guard let userId = notification.userInfo?["userId"] as? String,
                  let imageUrl = notification.userInfo?["imageUrl"] as? String,
                  userId == workout.userId else { return }
            
            Task { @MainActor in
                profileImageUrl = imageUrl
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 
