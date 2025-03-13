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
            // Create a deep copy of the current exercises state
            var exercisesCopy: [Exercise] = []
            for exercise in exercises {
                var exerciseCopy = exercise
                exerciseCopy.sets = exercise.sets // This creates a copy of the sets array
                exercisesCopy.append(exerciseCopy)
            }
            
            workout.exercises = exercisesCopy
            workout.duration = workoutDuration
            workout.createdAt = workoutStartTime ?? Date()
        }
        
        // Then save to Firestore
        let encodedWorkout = try Firestore.Encoder().encode(workout)
        try await db.collection("workouts").document(workout.id ?? UUID().uuidString).setData(encodedWorkout)
        
        // Finally, reset the state
        await MainActor.run {
            // Clear everything after successful save
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
} 