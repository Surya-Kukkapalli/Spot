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
        // Initialize with default values if needed
    }
    
    func startNewWorkout(name: String) {
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
        self.isWorkoutInProgress = true
        self.workoutStartTime = Date()
    }
    
    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
    }
    
    func addExercise(name: String, equipment: Equipment) {
        let exercise = Exercise(
            id: UUID().uuidString,
            name: name,
            sets: [],
            equipment: equipment
        )
        exercises.append(exercise)
    }
    
    func addSet(to exerciseIndex: Int) {
        guard exerciseIndex < exercises.count else { return }
        let newSet = ExerciseSet(id: UUID().uuidString)
        exercises[exerciseIndex].sets.append(newSet)
    }
    
    func removeSet(from exerciseIndex: Int, at setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }
    
    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
    }
    
    func startRestTimer(seconds: TimeInterval) {
        remainingRestTime = seconds
        currentRestTimer?.invalidate()
        
        currentRestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.remainingRestTime > 0 {
                    self.remainingRestTime -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
    
    func finishWorkout() async throws {
        guard var workout = activeWorkout else { return }
        
        // First, update the workout object with current state
        await MainActor.run {
            var exercisesCopy: [Exercise] = []
            for exercise in exercises {
                print("Processing exercise: \(exercise.name)")
                print("Number of sets: \(exercise.sets.count)")
                exercise.sets.forEach { set in
                    print("Set: \(set.weight)lbs × \(set.reps) reps")
                }
                
                var exerciseCopy = exercise
                exerciseCopy.sets = exercise.sets
                exercisesCopy.append(exerciseCopy)
            }
            
            workout.exercises = exercisesCopy
            workout.duration = workoutDuration
            workout.createdAt = workoutStartTime ?? Date()
        }
        
        // Save the workout
        let encodedWorkout = try Firestore.Encoder().encode(workout)
        try await db.collection("workouts").document(workout.id).setData(encodedWorkout)
        
        // Create and save workout summary
        if let currentUser = Auth.auth().currentUser {
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            let user = try userDoc.data(as: User.self)
            
            // Create exercise summaries
            let exerciseSummaries = workout.exercises.map { exercise -> WorkoutSummary.Exercise in
                print("Creating summary for exercise: \(exercise.name)")
                print("Number of sets to save: \(exercise.sets.count)")
                
                let sets = exercise.sets.map { set -> WorkoutSummary.Exercise.Set in
                    print("Converting set: \(set.weight)lbs × \(set.reps) reps")
                    return WorkoutSummary.Exercise.Set(
                        weight: set.weight,
                        reps: set.reps
                    )
                }
                
                return WorkoutSummary.Exercise(
                    exerciseName: exercise.name,
                    imageUrl: exercise.gifUrl,
                    targetMuscle: exercise.target,
                    sets: sets
                )
            }
            
            // Create personal records dictionary
            let personalRecords: [String: PersonalRecord] = [:]
            
            // Create workout summary
            let summary = WorkoutSummary(
                id: workout.id,
                userId: user.id ?? "",
                username: user.username,
                userProfileImageUrl: user.profileImageUrl,
                workoutTitle: workout.name,
                workoutNotes: workout.notes,
                date: workout.createdAt,
                duration: Int(workout.duration / 60), // Convert seconds to minutes
                totalVolume: calculateVolume(),
                fistBumps: 0,
                comments: 0,
                exercises: exerciseSummaries,
                personalRecords: personalRecords
            )
            
            print("Final workout summary:")
            print("Number of exercises: \(summary.exercises.count)")
            
            // Check for PRs before saving
            let prService = PersonalRecordService()
            var updatedSummary = summary
            var newPRs: [String: PersonalRecord] = [:]
            
            for (exerciseIndex, exercise) in summary.exercises.enumerated() {
                if let isPR = try? await prService.checkAndUpdatePR(
                    userId: user.id ?? "",
                    exercise: exercise,
                    workoutId: workout.id
                ), isPR {
                    // Update exercise to mark PR
                    var updatedExercise = exercise
                    updatedExercise.hasPR = true
                    
                    // Find the best set and mark it as PR
                    if let bestSet = exercise.bestSet,
                       let bestSetIndex = exercise.sets.firstIndex(where: { $0.volume == bestSet.volume }) {
                        var updatedSets = exercise.sets
                        updatedSets[bestSetIndex].isPR = true
                        updatedExercise.sets = updatedSets
                        
                        // Create PR record
                        let pr = PersonalRecord(
                            id: UUID().uuidString,
                            exerciseName: exercise.exerciseName,
                            weight: bestSet.weight,
                            reps: bestSet.reps,
                            oneRepMax: bestSet.oneRepMax,
                            date: workout.createdAt,
                            workoutId: workout.id,
                            userId: user.id ?? ""
                        )
                        newPRs[exercise.exerciseName] = pr
                        
                        // Update exercise in summary
                        var updatedExercises = updatedSummary.exercises
                        updatedExercises[exerciseIndex] = updatedExercise
                        updatedSummary.exercises = updatedExercises
                    }
                }
            }
            
            if !newPRs.isEmpty {
                updatedSummary.personalRecords = newPRs
            }
            
            // Save the workout summary
            try await db.collection("workout_summaries")
                .document(workout.id)
                .setData(from: updatedSummary)
            
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

    
    func createWorkoutSummary(from workout: Workout, user: User) -> WorkoutSummary {
        // Create exercise summaries
        let exerciseSummaries = workout.exercises.map { exercise -> WorkoutSummary.Exercise in
            return WorkoutSummary.Exercise(
                exerciseName: exercise.name,
                imageUrl: exercise.gifUrl,
                targetMuscle: exercise.target,
                sets: exercise.sets.map { set in
                    WorkoutSummary.Exercise.Set(
                        weight: set.weight,
                        reps: set.reps
                    )
                }
            )
        }
        
        // Create personal records dictionary
        let personalRecords: [String: PersonalRecord] = [:]
        
        return WorkoutSummary(
            id: workout.id,
            userId: user.id ?? "",
            username: user.username,
            userProfileImageUrl: user.profileImageUrl,
            workoutTitle: workout.name,
            workoutNotes: workout.notes,
            date: workout.createdAt,
            duration: Int(workout.duration / 60), // Convert seconds to minutes
            totalVolume: calculateVolume(),
            fistBumps: workout.likes,
            comments: workout.comments,
            exercises: exerciseSummaries,
            personalRecords: personalRecords
        )
    }
} 
