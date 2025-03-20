import SwiftUI
import Charts

struct WorkoutDetailView: View {
    let workout: WorkoutSummary
    @StateObject private var interactionViewModel = WorkoutInteractionViewModel()
    @State private var hasLiked = false
    @State private var showComments = false
    @State private var fistBumpCount: Int
    @State private var commentCount: Int
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingPRAlert = false
    @State private var prMessage = ""
    
    init(workout: WorkoutSummary) {
        self.workout = workout
        _fistBumpCount = State(initialValue: workout.fistBumps)
        _commentCount = State(initialValue: workout.comments)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                WorkoutHeaderView(workout: workout)
                    .id(workout.id)
                
                WorkoutStatsView(workout: workout)
                    .id(workout.id)
                
                WorkoutInteractionButtonsView(
                    workout: workout,
                    hasLiked: $hasLiked,
                    showComments: $showComments,
                    fistBumpCount: $fistBumpCount,
                    commentCount: $commentCount,
                    interactionViewModel: interactionViewModel
                )
                .id(workout.id)
                
                // Add Muscle Split View
                if !workout.muscleSplit.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Muscle Split")
                            .font(.title3)
                            .padding(.bottom, 4)
                        
                        ForEach(workout.muscleSplit, id: \.muscle) { split in
                            let percentage = Double(split.sets) / Double(workout.exercises.reduce(0) { $0 + $1.sets.count }) * 100
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(split.muscle)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(percentage))%")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * CGFloat(percentage) / 100)
                                        .frame(height: 8)
                                }
                                .frame(height: 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                WorkoutExercisesView(
                    workout: workout,
                    showingPRAlert: $showingPRAlert,
                    prMessage: $prMessage
                )
                .id(workout.id)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = authViewModel.currentUser?.id {
                hasLiked = await interactionViewModel.checkIfLiked(
                    workoutId: workout.id,
                    userId: userId
                )
            }
        }
        .alert("Personal Record 🏆", isPresented: $showingPRAlert) {
            Button("Nice!", role: .cancel) { }
        } message: {
            Text(prMessage)
        }
    }
}

// MARK: - Header View
private struct WorkoutHeaderView: View {
    let workout: WorkoutSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: workout.userProfileImageUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(workout.username)
                        .font(.headline)
                    Text(workout.date.formatted())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Text(workout.workoutTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            if let notes = workout.workoutNotes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Stats View
private struct WorkoutStatsView: View {
    let workout: WorkoutSummary
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 48) {
                VStack(alignment: .center) {
                    Text("\(workout.duration)")
                        .font(.title3)
                        .bold()
                    Text("minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .center) {
                    Text("\(workout.totalVolume)")
                        .font(.title3)
                        .bold()
                    Text("volume")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let records = workout.personalRecords, !records.isEmpty {
                    VStack(alignment: .center) {
                        Text("\(records.count)")
                            .font(.title3)
                            .bold()
                        Text("PRs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 2)
            
            // Text("Muscle Split")
            //     .font(.title3)
            //     .padding(.top, 16)
            
            // // Debug print for muscle split data
            // .onAppear {
            //     print("Muscle Split Data:")
            //     workout.muscleSplit.forEach { split in
            //         print("Muscle: \(split.muscle), Sets: \(split.sets)")
            //     }
                
            //     print("\nExercise Data:")
            //     workout.exercises.forEach { exercise in
            //         print("Exercise: \(exercise.exerciseName)")
            //         print("Target Muscle: \(exercise.targetMuscle)")
            //         print("Sets count: \(exercise.sets.count)")
            //         exercise.sets.forEach { set in
            //             print("Set: \(set.weight)lbs × \(set.reps) reps")
            //         }
            //     }
            // }
            
            // VStack(alignment: .leading, spacing: 8) {
            //     ForEach(workout.muscleSplit, id: \.muscle) { split in
            //         VStack(alignment: .leading, spacing: 4) {
            //             HStack {
            //                 Text(split.muscle)
            //                     .font(.subheadline)
            //                 Spacer()
            //                 Text("\(split.sets) sets")
            //                     .font(.subheadline)
            //                     .foregroundColor(.secondary)
            //             }
                        
            //             GeometryReader { geometry in
            //                 Rectangle()
            //                     .fill(Color.blue)
            //                     .frame(
            //                         width: geometry.size.width * CGFloat(split.sets) / CGFloat(workout.exercises.reduce(0) { $0 + $1.sets.count }),
            //                         height: 8
            //                     )
            //             }
            //             .frame(height: 8)
            //             .background(Color(.systemGray5))
            //             .cornerRadius(4)
            //         }
            //     }
            // }
        }
    }
}

// MARK: - Interaction Buttons View
private struct WorkoutInteractionButtonsView: View {
    let workout: WorkoutSummary
    @Binding var hasLiked: Bool
    @Binding var showComments: Bool
    @Binding var fistBumpCount: Int
    @Binding var commentCount: Int
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var interactionViewModel: WorkoutInteractionViewModel
    
    var body: some View {
        HStack {
            Spacer()
            Button {
                if hasLiked {
                    // Show details when already liked
                } else {
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
                }
            } label: {
                HStack {
                    Image(systemName: hasLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    Text("\(fistBumpCount)")
                }
            }
            
            Spacer()
            Divider().frame(height: 20)
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
                NavigationStack {
                    CommentView(workout: workout) { newCount in
                        commentCount = newCount
                    }
                }
            }
            
            Spacer()
            Divider().frame(height: 20)
            Spacer()
            
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            Spacer()
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Exercises View
private struct WorkoutExercisesView: View {
    let workout: WorkoutSummary
    @Binding var showingPRAlert: Bool
    @Binding var prMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Exercises")
                .font(.title3)
            
            ForEach(workout.exercises, id: \.exerciseName) { exercise in
                ExerciseWorkoutRowView(
                    exercise: exercise,
                    showingPRAlert: $showingPRAlert,
                    prMessage: $prMessage,
                    username: workout.username
                )
                
                if exercise.id != workout.exercises.last?.id {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Exercise Row View
private struct ExerciseWorkoutRowView: View {
    let exercise: WorkoutSummary.Exercise
    @Binding var showingPRAlert: Bool
    @Binding var prMessage: String
    let username: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // Exercise Image and Name
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: exercise.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.headline)
                        Text(exercise.targetMuscle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Analytics and PR Badge
                HStack(spacing: 8) {
                    NavigationLink {
                        ExerciseDetailsView(exercise: ExerciseTemplate(
                            id: UUID().uuidString,
                            name: exercise.exerciseName,
                            bodyPart: exercise.targetMuscle,
                            equipment: "unknown",
                            gifUrl: exercise.imageUrl,
                            target: exercise.targetMuscle,
                            secondaryMuscles: [],
                            instructions: []
                        ))
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.gray)
                    }
                    
                    if exercise.hasPR {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("New PR!")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Sets table header
            HStack {
                Text("Set")
                    .frame(width: 40, alignment: .leading)
                Text("Weight")
                    .frame(width: 80, alignment: .leading)
                Text("Reps")
                    .frame(width: 60, alignment: .leading)
                Text("Volume")
                    .frame(width: 80, alignment: .leading)
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
            
            // Sets list
            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                HStack {
                    Text("\(index + 1)")
                        .frame(width: 40, alignment: .leading)
                    Text("\(Int(set.weight))lbs")
                        .frame(width: 80, alignment: .leading)
                    Text("\(set.reps)")
                        .frame(width: 60, alignment: .leading)
                    Text("\(Int(set.weight * Double(set.reps)))")
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    if set.isPR {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
        }
    }
    
    private func showPRTooltip(exercise: String, weight: Double, reps: Int) {
        prMessage = "New Personal Record! \(username) achieved \(String(format: "%.1f", weight))lbs × \(reps) reps on \(exercise)"
        showingPRAlert = true
    }
} 
