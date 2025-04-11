import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import ActivityKit

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var activeWorkout: Workout?
    @Published var exercises: [Exercise] = []
    @Published var isWorkoutInProgress = false
    @Published var workoutStartTime: Date?
    @Published var currentRestTimer: Timer?
    @Published var remainingRestTime: TimeInterval = 0
    private var restActivity: Activity<RestTimerAttributes>?
    
    var workoutDuration: TimeInterval {
        guard let startTime = workoutStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    private let db = Firestore.firestore()
    
    init() {
        print("DEBUG: Initializing WorkoutViewModel")
    }
    
    func startNewWorkout(name: String) {
        print("DEBUG: Starting new workout with name: \(name)")
        let workout = Workout(
            id: UUID().uuidString,
            userId: Auth.auth().currentUser?.uid ?? "",
            name: name,
            exercises: [],
            duration: 0,
            createdAt: Date(),
            isTemplate: false,
            likes: 0,
            comments: 0,
            shares: 0
        )
        
        self.activeWorkout = workout
        self.exercises = []
        self.workoutStartTime = Date()
        self.isWorkoutInProgress = true
        print("DEBUG: Workout initialized with ID: \(workout.id)")
        print("DEBUG: isWorkoutInProgress set to: \(isWorkoutInProgress)")
    }
    
    func updateActiveWorkout(name: String, notes: String?) {
        guard var workout = activeWorkout else {
            print("DEBUG: Cannot update workout - no active workout")
            return
        }
        
        print("DEBUG: Updating active workout")
        print("DEBUG: - Old name: '\(workout.name)'")
        print("DEBUG: - New name: '\(name)'")
        print("DEBUG: - Old notes: '\(workout.notes ?? "none")'")
        print("DEBUG: - New notes: '\(notes ?? "none")'")
        
        workout.name = name
        workout.notes = notes
        workout.exercises = exercises // Ensure exercises are up to date
        activeWorkout = workout
        
        print("DEBUG: Active workout updated successfully")
    }
    
    func addExercise(_ exercise: Exercise) {
        print("DEBUG: Adding exercise to workout: \(exercise.name)")
        print("DEBUG: Current exercises count: \(exercises.count)")
        
        // Add initial set
        var exerciseWithSet = exercise
        exerciseWithSet.sets.append(ExerciseSet(id: UUID().uuidString))
        
        exercises.append(exerciseWithSet)
        print("DEBUG: New exercises count: \(exercises.count)")
        
        // Update active workout's exercises
        if var workout = activeWorkout {
            print("DEBUG: Updating active workout exercises")
            workout.exercises = exercises
            activeWorkout = workout
            print("DEBUG: Active workout updated with \(workout.exercises.count) exercises")
        } else {
            print("DEBUG: Warning: No active workout when adding exercise")
        }
    }
    
    func addExercise(name: String, equipment: Equipment) {
        print("DEBUG: Creating new exercise with name: \(name)")
        let exercise = Exercise(
            id: UUID().uuidString,
            name: name,
            sets: [],
            equipment: equipment
        )
        exercises.append(exercise)
        print("DEBUG: Added exercise with equipment. Total exercises: \(exercises.count)")
    }
    
    func addSet(to exerciseIndex: Int) {
        guard exerciseIndex < exercises.count else {
            print("DEBUG: Failed to add set - invalid exercise index: \(exerciseIndex)")
            return
        }
        let newSet = ExerciseSet(id: UUID().uuidString)
        exercises[exerciseIndex].sets.append(newSet)
        print("DEBUG: Added set to exercise at index \(exerciseIndex). Total sets: \(exercises[exerciseIndex].sets.count)")
    }
    
    func removeSet(from exerciseIndex: Int, at setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else {
            print("DEBUG: Failed to remove set - invalid indices: exercise \(exerciseIndex), set \(setIndex)")
            return
        }
        exercises[exerciseIndex].sets.remove(at: setIndex)
        print("DEBUG: Removed set \(setIndex) from exercise \(exerciseIndex)")
    }
    
    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else {
            print("DEBUG: Failed to remove exercise - invalid index: \(index)")
            return
        }
        let exercise = exercises[index]
        exercises.remove(at: index)
        print("DEBUG: Removed exercise: \(exercise.name). Remaining exercises: \(exercises.count)")
    }
    
    func startRestTimer(seconds: TimeInterval, exerciseName: String, setNumber: Int) {
        remainingRestTime = seconds
        currentRestTimer?.invalidate()
        print("DEBUG: Starting rest timer for \(seconds) seconds")
        
        if #available(iOS 16.1, *) {
            // Start live activity
            let endTime = Date().addingTimeInterval(seconds)
            let attributes = RestTimerAttributes(exerciseName: exerciseName, setNumber: setNumber)
            let contentState = RestTimerAttributes.ContentState(
                endTime: endTime,
                remainingTime: seconds
            )
            
            Task {
                do {
                    restActivity = try await Activity.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: nil
                    )
                } catch {
                    print("DEBUG: Error starting live activity: \(error)")
                }
            }
        }
        
        currentRestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.remainingRestTime > 0 {
                    self.remainingRestTime -= 1
                    
                    if #available(iOS 16.1, *) {
                        // Update live activity
                        let contentState = RestTimerAttributes.ContentState(
                            endTime: Date().addingTimeInterval(self.remainingRestTime),
                            remainingTime: self.remainingRestTime
                        )
                        await self.restActivity?.update(using: contentState)
                    }
                } else {
                    timer.invalidate()
                    if #available(iOS 16.1, *) {
                        await self.restActivity?.end(dismissalPolicy: .immediate)
                    }
                    print("DEBUG: Rest timer completed")
                }
            }
        }
    }
    
    func finishWorkout() async throws {
        guard var workout = activeWorkout else {
            print("DEBUG: No active workout to finish")
            return
        }
        
        // First, update the workout object with current state
        workout.exercises = exercises
        workout.duration = workoutDuration
        workout.createdAt = workoutStartTime ?? Date()
        
        print("DEBUG: Finishing workout with \(exercises.count) exercises")
        print("DEBUG: Workout name: '\(workout.name)'")
        print("DEBUG: Workout notes: '\(workout.notes ?? "none")'")
        print("DEBUG: Exercise details:")
        for exercise in exercises {
            print("- \(exercise.name): \(exercise.sets.count) sets")
            for set in exercise.sets {
                print("  * \(set.weight)lbs × \(set.reps) reps")
            }
        }
        
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG: No current user found")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
        }
        print("DEBUG: Current user ID: \(currentUser.uid)")
        
        // Get user data
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        let user = try userDoc.data(as: User.self)
        print("DEBUG: Retrieved user data for: \(user.username)")
        
        // Update workout with user info before saving
        workout.userId = currentUser.uid  // Ensure workout has correct user ID
        
        // Ensure workout name and notes are preserved
        if workout.name.isEmpty {
            print("DEBUG: Warning: Workout name is empty, this shouldn't happen")
        }
        
        // Save the workout first with complete data
        let encodedWorkout = try Firestore.Encoder().encode(workout)
        try await db.collection("workouts").document(workout.id).setData(encodedWorkout)
        print("DEBUG: Saved workout to workouts collection")
        print("DEBUG: - Name: '\(workout.name)'")
        print("DEBUG: - Notes: '\(workout.notes ?? "none")'")
        
        // Create exercise summaries and check for PRs
        let prService = PersonalRecordService()
        var personalRecords: [String: PersonalRecord] = [:]
        
        let exerciseSummaries = try await withThrowingTaskGroup(of: (WorkoutSummary.Exercise, PersonalRecord?).self) { group in
            for exercise in exercises {
                group.addTask {
                    let sets = exercise.sets.map { set -> WorkoutSummary.Exercise.Set in
                        return WorkoutSummary.Exercise.Set(
                            weight: set.weight,
                            reps: set.reps,
                            isPR: false  // Will be updated if it's a PR
                        )
                    }
                    
                    var summaryExercise = WorkoutSummary.Exercise(
                        exerciseName: exercise.name,
                        imageUrl: exercise.gifUrl,
                        targetMuscle: exercise.target,
                        sets: sets,
                        hasPR: false
                    )
                    
                    // Check if any set is a PR
                    if let bestSet = exercise.sets.max(by: { $0.volume < $1.volume }) {
                        let isPR = try await prService.checkAndUpdatePR(
                            userId: currentUser.uid,
                            exercise: summaryExercise,
                            workoutId: workout.id
                        )
                        
                        if isPR {
                            // Update the set that was a PR
                            if let prSetIndex = summaryExercise.sets.firstIndex(where: { 
                                $0.weight == bestSet.weight && $0.reps == bestSet.reps 
                            }) {
                                summaryExercise.sets[prSetIndex].isPR = true
                            }
                            summaryExercise.hasPR = true
                            
                            // Create PR record
                            let pr = PersonalRecord(
                                id: UUID().uuidString,
                                exerciseName: exercise.name,
                                weight: bestSet.weight,
                                reps: bestSet.reps,
                                oneRepMax: OneRepMax.calculate(weight: bestSet.weight, reps: bestSet.reps),
                                date: workout.createdAt,
                                workoutId: workout.id,
                                userId: currentUser.uid
                            )
                            return (summaryExercise, pr)
                        }
                    }
                    
                    return (summaryExercise, nil)
                }
            }
            
            var summaries: [WorkoutSummary.Exercise] = []
            for try await (exercise, pr) in group {
                summaries.append(exercise)
                if let pr = pr {
                    personalRecords[pr.exerciseName] = pr
                }
            }
            return summaries
        }
        
        // Create workout summary
        let summary = WorkoutSummary(
            id: workout.id,
            userId: currentUser.uid,
            username: user.username,
            userProfileImageUrl: user.profileImageUrl,
            workoutTitle: workout.name,
            workoutNotes: workout.notes,
            createdAt: workout.createdAt,
            duration: Int(workout.duration / 60),
            totalVolume: calculateVolume(),
            fistBumps: workout.likes,
            comments: workout.comments,
            exercises: exerciseSummaries,
            personalRecords: personalRecords
        )
        
        // Save the workout summary
        let encodedSummary = try Firestore.Encoder().encode(summary)
        try await db.collection("workoutSummaries")
            .document(workout.id)
            .setData(encodedSummary)
        print("DEBUG: Saved workout summary to workoutSummaries collection")
        
        // Track challenge progress
        let challengeProgressService = ChallengeProgressService()
        print("DEBUG: Starting to track workout progress for challenges")
        print("DEBUG: Workout summary - Total Volume: \(summary.totalVolume)")
        print("DEBUG: Workout summary - Exercise count: \(summary.exercises.count)")
        try await challengeProgressService.trackWorkoutProgress(summary, userId: currentUser.uid)
        print("DEBUG: Completed tracking workout progress for challenges")
        
        // Notify PR service to refresh caches if needed
        if !personalRecords.isEmpty {
            print("DEBUG: New PRs detected, refreshing PR caches...")
            for pr in personalRecords.values {
                // Update PR in personal_records collection
                try await db.collection("users")
                    .document(currentUser.uid)
                    .collection("personal_records")
                    .document(pr.exerciseName)
                    .setData(try Firestore.Encoder().encode(pr))
            }
            print("DEBUG: PR caches updated")
        }
        
        // Update user's workout stats
        var userData: [String: Any] = [:]
        userData["workoutsCompleted"] = FieldValue.increment(Int64(1))
        userData["totalWorkoutDuration"] = FieldValue.increment(Int64(workout.duration))
        
        if let currentWorkouts = user.workoutsCompleted {
            let newAverage = ((user.totalWorkoutDuration ?? 0) + workout.duration) / Double(currentWorkouts + 1)
            userData["averageWorkoutDuration"] = newAverage
        }
        
        try await db.collection("users")
            .document(currentUser.uid)
            .updateData(userData)
        print("DEBUG: Updated user workout stats")
        
        // Reset the workout state
        await MainActor.run {
            self.activeWorkout = nil
            self.exercises = []
            self.isWorkoutInProgress = false
            self.workoutStartTime = nil
            self.currentRestTimer?.invalidate()
            self.currentRestTimer = nil
            self.remainingRestTime = 0
        }
        print("DEBUG: Workout state reset")
    }
    
    func discardWorkout() async {
        self.activeWorkout = nil
        self.exercises = []
        self.isWorkoutInProgress = false
        self.workoutStartTime = nil
    }
    
    func calculateVolume() -> Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + Int(set.weight * Double(set.reps))
            }
        }
    }
    
    func calculateTotalSets() -> Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    
    func createWorkoutSummary(from workout: Workout, user: User) async throws -> WorkoutSummary {
        // Create exercise summaries and check for PRs
        let prService = PersonalRecordService()
        var personalRecords: [String: PersonalRecord] = [:]
        
        let exerciseSummaries = try await withThrowingTaskGroup(of: (WorkoutSummary.Exercise, PersonalRecord?).self) { group in
            for exercise in workout.exercises {
                group.addTask {
                    let sets = exercise.sets.map { set -> WorkoutSummary.Exercise.Set in
                        return WorkoutSummary.Exercise.Set(
                            weight: set.weight,
                            reps: set.reps,
                            isPR: false  // Will be updated if it's a PR
                        )
                    }
                    
                    var summaryExercise = WorkoutSummary.Exercise(
                        exerciseName: exercise.name,
                        imageUrl: exercise.gifUrl,
                        targetMuscle: exercise.target ?? "Other",
                        sets: sets,
                        hasPR: false
                    )
                    
                    // Check if any set is a PR
                    if let bestSet = exercise.sets.max(by: { $0.volume < $1.volume }) {
                        let isPR = try await prService.checkAndUpdatePR(
                            userId: user.id ?? "",
                            exercise: summaryExercise,
                            workoutId: workout.id
                        )
                        
                        if isPR {
                            // Update the set that was a PR
                            if let prSetIndex = summaryExercise.sets.firstIndex(where: { 
                                $0.weight == bestSet.weight && $0.reps == bestSet.reps 
                            }) {
                                summaryExercise.sets[prSetIndex].isPR = true
                            }
                            summaryExercise.hasPR = true
                            
                            // Create PR record
                            let pr = PersonalRecord(
                                id: UUID().uuidString,
                                exerciseName: exercise.name,
                                weight: bestSet.weight,
                                reps: bestSet.reps,
                                oneRepMax: OneRepMax.calculate(weight: bestSet.weight, reps: bestSet.reps),
                                date: workout.createdAt,
                                workoutId: workout.id,
                                userId: user.id ?? ""
                            )
                            return (summaryExercise, pr)
                        }
                    }
                    
                    return (summaryExercise, nil)
                }
            }
            
            var summaries: [WorkoutSummary.Exercise] = []
            for try await (exercise, pr) in group {
                summaries.append(exercise)
                if let pr = pr {
                    personalRecords[pr.exerciseName] = pr
                }
            }
            return summaries
        }
        
        return WorkoutSummary(
            id: workout.id,
            userId: user.id ?? "",
            username: user.username,
            userProfileImageUrl: user.profileImageUrl,
            workoutTitle: workout.name,
            workoutNotes: workout.notes,
            createdAt: workout.createdAt,
            duration: Int(workout.duration / 60), // Convert seconds to minutes
            totalVolume: calculateVolume(),
            fistBumps: workout.likes,
            comments: workout.comments,
            exercises: exerciseSummaries,
            personalRecords: personalRecords
        )
    }
} 
