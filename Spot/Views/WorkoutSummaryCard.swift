import SwiftUI

struct WorkoutSummaryCard: View {
    let workout: WorkoutSummary
    @StateObject private var interactionViewModel = WorkoutInteractionViewModel()
    @State private var hasLiked = false
    @State private var fistBumpCount: Int
    @State private var commentCount: Int
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showComments = false
    
    init(workout: WorkoutSummary) {
        self.workout = workout
        _fistBumpCount = State(initialValue: workout.fistBumps)
        _commentCount = State(initialValue: workout.comments)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack {
                AsyncImage(url: URL(string: workout.userProfileImageUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.username)
                        .font(.headline)
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
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
                    NavigationStack {
                        CommentView(workout: workout, onCommentAdded: { newCount in
                            commentCount = newCount
                        })
                    }
                }
                
                Spacer()
                Divider()
                    .frame(height: 20)
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
    }
} 
