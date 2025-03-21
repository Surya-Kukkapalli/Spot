import Foundation
import FirebaseFirestore

class PersonalRecordService {
    private let db = Firestore.firestore()
    
    func checkAndUpdatePR(userId: String, exercise: WorkoutSummary.Exercise, workoutId: String) async throws -> Bool {
        guard let bestSet = exercise.bestSet else { return false }
        
        let exerciseRef = db.collection("users")
            .document(userId)
            .collection("exerciseRecords")
            .document(exercise.exerciseName)
        
        let snapshot = try await exerciseRef.getDocument()
        
        if let data = snapshot.data(),
           let currentMaxWeight = data["maxWeight"] as? Double {
            // Check if this is a new PR
            if bestSet.weight > currentMaxWeight {
                try await updatePersonalRecord(
                    userId: userId,
                    exerciseName: exercise.exerciseName,
                    weight: bestSet.weight,
                    reps: bestSet.reps
                )
                return true
            }
            return false
        } else {
            // No previous record exists, so this is a PR
            try await updatePersonalRecord(
                userId: userId,
                exerciseName: exercise.exerciseName,
                weight: bestSet.weight,
                reps: bestSet.reps
            )
            return true
        }
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
    
    private func updatePersonalRecord(userId: String, exerciseName: String, weight: Double, reps: Int) async throws {
        let exerciseRef = db.collection("users")
            .document(userId)
            .collection("exerciseRecords")
            .document(exerciseName)
        
        try await exerciseRef.setData([
            "maxWeight": weight,
            "reps": reps,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }
    
    func getPersonalRecord(userId: String, exerciseName: String) async throws -> (weight: Double, reps: Int)? {
        let exerciseRef = db.collection("users").document(userId).collection("exerciseRecords").document(exerciseName)
        let snapshot = try await exerciseRef.getDocument()
        
        guard let data = snapshot.data(),
              let weight = data["maxWeight"] as? Double,
              let reps = data["reps"] as? Int else {
            return nil
        }
        
        return (weight, reps)
    }
} 
