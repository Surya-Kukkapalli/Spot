import Foundation
import FirebaseFirestore

class PersonalRecordService {
    private let db = Firestore.firestore()
    
    func checkAndUpdatePR(userId: String, exercise: WorkoutSummary.Exercise, workoutId: String) async throws -> Bool {
        let exerciseName = exercise.exerciseName.replacingOccurrences(of: "/", with: "_")
        let exerciseRef = db.collection("users").document(userId)
            .collection("personal_records").document(exerciseName)
        
        let result = try await exerciseRef.getDocument()
        let currentOneRepMax = exercise.bestSet?.weight ?? 0
        let bestSet = exercise.bestSet
        
        if !result.exists {
            // No PR exists yet, create one
            if let set = bestSet {
                try await exerciseRef.setData([
                    "exerciseName": exercise.exerciseName,
                    "weight": set.weight,
                    "reps": set.reps,
                    "oneRepMax": currentOneRepMax,
                    "date": Timestamp(date: Date()),
                    "workoutId": workoutId,
                    "userId": userId
                ])
                return true
            }
            return false
        }
        
        // Check if current set beats the PR
        guard let data = result.data(),
              let prWeight = data["weight"] as? Double,
              let prReps = data["reps"] as? Int,
              let prOneRepMax = data["oneRepMax"] as? Double else {
            return false
        }
        
        if currentOneRepMax > prOneRepMax {
            // Update PR
            if let set = bestSet {
                try await exerciseRef.updateData([
                    "weight": set.weight,
                    "reps": set.reps,
                    "oneRepMax": currentOneRepMax,
                    "date": Timestamp(date: Date()),
                    "workoutId": workoutId
                ])
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
    
    func fetchPersonalRecords(userId: String) async throws -> [PersonalRecord] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("personal_records").getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: PersonalRecord.self)
        }
    }
} 
