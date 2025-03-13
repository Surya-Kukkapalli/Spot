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
    
    private let db = Firestore.firestore()
    
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
        
        workout.exercises = exercises
        workout.duration = Date().timeIntervalSince(workoutStartTime ?? Date())
        
        let encodedWorkout = try Firestore.Encoder().encode(workout)
        let workoutId = workout.id ?? UUID().uuidString
        try await db.collection("workouts").document(workoutId).setData(encodedWorkout)
        
        // Reset state
        self.activeWorkout = nil
        self.exercises = []
        self.isWorkoutInProgress = false
        self.workoutStartTime = nil
    }
} 