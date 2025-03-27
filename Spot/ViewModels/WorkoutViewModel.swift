import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var activeWorkout: Workout?
    @Published var exercises: [Exercise] = []
    @Published var isWorkoutInProgress = false
    @Published var workoutStartTime: Date?
    @Published var currentRestTimer: Timer?
    @Published var remainingRestTime: TimeInterval = 0
    
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
    
    func addExercise(_ exercise: Exercise) {
        print("DEBUG: Adding exercise to workout: \(exercise.name)")
        print("DEBUG: Current exercises count: \(exercises.count)")
        exercises.append(exercise)
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
    
    func startRestTimer(seconds: TimeInterval) {
        remainingRestTime = seconds
        currentRestTimer?.invalidate()
        print("DEBUG: Starting rest timer for \(seconds) seconds")
        
        currentRestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.remainingRestTime > 0 {
                    self.remainingRestTime -= 1
                } else {
                    timer.invalidate()
                    print("DEBUG: Rest timer completed")
                }
            }
        }
    }
    
    func finishWorkout() async throws {
        guard var workout = activeWorkout else { return }
        
        // First, update the workout object with current state
        workout.exercises = exercises
        workout.duration = workoutDuration
        workout.createdAt = workoutStartTime ?? Date()
        
        print("DEBUG: Finishing workout with \(exercises.count) exercises")
        print("DEBUG: Exercise details:")
        for exercise in exercises {
            print("- \(exercise.name): \(exercise.sets.count) sets")
            for set in exercise.sets {
                print("  * \(set.weight)lbs × \(set.reps) reps")
            }
        }
        
        // Save the workout
        let encodedWorkout = try Firestore.Encoder().encode(workout)
        try await db.collection("workouts").document(workout.id).setData(encodedWorkout)
        print("DEBUG: Saved workout to workouts collection")
        
        // Create and save workout summary
        if let currentUser = Auth.auth().currentUser {
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            let user = try userDoc.data(as: User.self)
            
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
            
            // Create workout summary
            let summary = WorkoutSummary(
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
            
            print("DEBUG: Final workout summary:")
            print("DEBUG: Title: \(summary.workoutTitle)")
            print("DEBUG: Number of exercises: \(summary.exercises.count)")
            print("DEBUG: Created at: \(summary.createdAt)")
            
            // Save the workout summary
            let encodedSummary = try Firestore.Encoder().encode(summary)
            try await db.collection("workoutSummaries")
                .document(workout.id)
                .setData(encodedSummary)
            print("DEBUG: Saved workout summary to workoutSummaries collection")
            
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
        }
        
        // Reset the workout state
        await MainActor.run {
            self.activeWorkout = nil
            self.exercises = []
            self.isWorkoutInProgress = false
            self.workoutStartTime = nil
        }
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
