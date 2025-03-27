import SwiftUI
import Firebase
import FirebaseFirestore

@MainActor
class WorkoutInteractionViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let prService = PersonalRecordService()
    @Published var workout: WorkoutSummary?
    
    func toggleLike(for workoutId: String, userId: String, isLiked: Bool) async throws {
        let likeRef = db.collection("workout_likes")
            .document("\(workoutId)_\(userId)")
        
        let summaryRef = db.collection("workoutSummaries")
            .document(workoutId)
        
        if isLiked {
            // Add like
            let likeData: [String: Any] = [
                "workoutId": workoutId,
                "userId": userId,
                "timestamp": Timestamp()
            ]
            try await likeRef.setData(likeData)
            
            let updateData: [String: Any] = [
                "fistBumps": FieldValue.increment(Int64(1))
            ]
            try await summaryRef.updateData(updateData)
        } else {
            // Remove like
            try await likeRef.delete()
            
            let updateData: [String: Any] = [
                "fistBumps": FieldValue.increment(Int64(-1))
            ]
            try await summaryRef.updateData(updateData)
        }
    }
    
    func checkIfLiked(workoutId: String, userId: String) async -> Bool {
        let likeRef = db.collection("workout_likes")
            .document("\(workoutId)_\(userId)")
        
        do {
            let doc = try await likeRef.getDocument()
            return doc.exists
        } catch {
            print("Error checking like status: \(error)")
            return false
        }
    }
    
    func checkForPRs(workout: WorkoutSummary) async {
        let workoutId = workout.id
        let userId = workout.userId
        
        var updatedWorkout = workout
        var personalRecords: [String: PersonalRecord] = [:] // Explicitly typed dictionary
        
        for (exerciseIndex, exercise) in workout.exercises.enumerated() {
            if let maxVolumeSet = exercise.sets.max(by: { $0.volume < $1.volume }) {
                do {
                    let isPR = try await prService.checkAndUpdatePR(
                        userId: userId,
                        exercise: exercise,
                        workoutId: workoutId
                    )
                    
                    if isPR {
                        var updatedExercise = exercise
                        updatedExercise.hasPR = true
                        
                        // Create PR record
                        let pr = PersonalRecord(
                            id: UUID().uuidString,
                            exerciseName: exercise.exerciseName,
                            weight: maxVolumeSet.weight,
                            reps: maxVolumeSet.reps,
                            oneRepMax: maxVolumeSet.oneRepMax,
                            date: workout.createdAt,
                            workoutId: workoutId,
                            userId: userId
                        )
                        personalRecords[exercise.exerciseName] = pr
                        
                        // Update sets to mark PR
                        var updatedSets = exercise.sets
                        if let prSetIndex = exercise.sets.firstIndex(where: { $0.volume == maxVolumeSet.volume }) {
                            updatedSets[prSetIndex].isPR = true
                        }
                        updatedExercise.sets = updatedSets
                        
                        // Update exercise in workout
                        var updatedExercises = updatedWorkout.exercises
                        updatedExercises[exerciseIndex] = updatedExercise
                        updatedWorkout.exercises = updatedExercises
                    }
                } catch {
                    print("Error checking PR: \(error)")
                }
            }
        }
        
        if !personalRecords.isEmpty {
            // Update Firestore with the new PRs
            do {
                // Convert personalRecords to a dictionary of [String: Any] for Firestore
                let prData = personalRecords.mapValues { pr -> [String: Any] in
                    return [
                        "exerciseName": pr.exerciseName,
                        "weight": pr.weight,
                        "reps": pr.reps,
                        "personalRecord": pr.oneRepMax,
                        "date": pr.date,
                        "workoutId": pr.workoutId,
                        "userId": pr.userId
                    ]
                }
                
                try await db.collection("workoutSummaries")
                    .document(workoutId)
                    .updateData(["personalRecords": prData])
                
                // Update local workout
                updatedWorkout.personalRecords = personalRecords
                self.workout = updatedWorkout
            } catch {
                print("Error updating personal records: \(error)")
            }
        }
    }
    
    func loadWorkout(id: String) async {
        do {
            let snapshot = try await db.collection("workoutSummaries")
                .document(id)
                .getDocument()
            
            self.workout = try snapshot.data(as: WorkoutSummary.self)
            
            // Check for PRs if workout is loaded
            if let workout = self.workout {
                await checkForPRs(workout: workout)
            }
        } catch {
            print("Error loading workout: \(error)")
        }
    }
} 
