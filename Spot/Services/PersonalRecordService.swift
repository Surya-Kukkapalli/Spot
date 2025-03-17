import Foundation
import FirebaseFirestore

class PersonalRecordService {
    private let db = Firestore.firestore()
    
    func checkAndUpdatePR(userId: String, exercise: WorkoutSummary.Exercise, workoutId: String) async throws -> Bool {
        let exerciseRef = db.collection("users").document(userId)
            .collection("personal_records").document(exercise.exerciseName)
        
        let currentOneRepMax = exercise.bestOneRepMax
        let bestSet = exercise.bestSet
        
        let result = try await exerciseRef.getDocument()
        
        if !result.exists {
            // First time performing this exercise, automatically a PR
            guard let bestSet = bestSet else { return false }
            
            let pr = PersonalRecord(
                id: UUID().uuidString,
                exerciseName: exercise.exerciseName,
                weight: bestSet.weight,
                reps: bestSet.reps,
                oneRepMax: currentOneRepMax,
                date: Date(),
                workoutId: workoutId,
                userId: userId
            )
            try exerciseRef.setData(from: pr)
            return true
        }
        
        // Check if current 1RM exceeds previous PR
        if let previousPR = try? result.data(as: PersonalRecord.self) {
            if currentOneRepMax > previousPR.oneRepMax {
                guard let bestSet = bestSet else { return false }
                
                let newPR = PersonalRecord(
                    id: UUID().uuidString,
                    exerciseName: exercise.exerciseName,
                    weight: bestSet.weight,
                    reps: bestSet.reps,
                    oneRepMax: currentOneRepMax,
                    date: Date(),
                    workoutId: workoutId,
                    userId: userId
                )
                try exerciseRef.setData(from: newPR)
                return true
            }
        }
        
        return false
    }
    
    func getPR(userId: String, exerciseName: String) async throws -> PersonalRecord? {
        let document = try await db.collection("users").document(userId)
            .collection("personal_records").document(exerciseName)
            .getDocument()
        
        return try? document.data(as: PersonalRecord.self)
    }
    
    func getAllPRs(userId: String) async throws -> [PersonalRecord] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("personal_records")
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: PersonalRecord.self) }
    }
} 
