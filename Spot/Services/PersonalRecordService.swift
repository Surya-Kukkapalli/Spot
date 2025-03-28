import Foundation
import FirebaseFirestore

class PersonalRecordService {
    private let db = Firestore.firestore()
    
    func checkAndUpdatePR(userId: String, exercise: WorkoutSummary.Exercise, workoutId: String) async throws -> Bool {
        print("DEBUG: Checking PR for exercise: '\(exercise.exerciseName)'")
        print("DEBUG: User ID: '\(userId)'")
        print("DEBUG: Workout ID: '\(workoutId)'")
        
        guard let bestSet = exercise.bestSet else {
            print("DEBUG: No best set found for exercise")
            return false
        }
        guard !exercise.exerciseName.isEmpty else {
            print("DEBUG: Exercise name is empty")
            return false
        }
        guard !userId.isEmpty else {
            print("DEBUG: User ID is empty")
            return false
        }
        
        print("DEBUG: Best set - Weight: \(bestSet.weight), Reps: \(bestSet.reps)")
        let bestSetOneRM = OneRepMax.calculate(weight: bestSet.weight, reps: bestSet.reps)
        print("DEBUG: Best set 1RM: \(bestSetOneRM)")
        
        // First, check if this is a PR in the exercise records
        let exerciseRef = db.collection("users")
            .document(userId)
            .collection("exerciseRecords")
            .document(exercise.exerciseName)
        
        let snapshot = try await exerciseRef.getDocument()
        print("DEBUG: Checking existing record for '\(exercise.exerciseName)'")
        
        let isPR: Bool
        if let data = snapshot.data(),
           let currentMaxWeight = data["maxWeight"] as? Double,
           let currentReps = data["reps"] as? Int {
            let currentOneRM = OneRepMax.calculate(weight: currentMaxWeight, reps: currentReps)
            print("DEBUG: Current record - Weight: \(currentMaxWeight), Reps: \(currentReps), 1RM: \(currentOneRM)")
            isPR = bestSetOneRM > currentOneRM
            print("DEBUG: Is PR? \(isPR) (New 1RM: \(bestSetOneRM) vs Current 1RM: \(currentOneRM))")
        } else {
            print("DEBUG: No previous record exists, this is a first-time PR")
            isPR = true
        }
        
        if isPR {
            print("DEBUG: New PR detected! Updating records...")
            // Update both exerciseRecords and personal_records collections
            try await updatePersonalRecord(
                userId: userId,
                exerciseName: exercise.exerciseName,
                weight: bestSet.weight,
                reps: bestSet.reps,
                workoutId: workoutId,
                date: Date()
            )
            print("DEBUG: PR records updated successfully")
        }
        
        return isPR
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
    
    private func updatePersonalRecord(userId: String, exerciseName: String, weight: Double, reps: Int, workoutId: String, date: Date) async throws {
        print("DEBUG: Updating PR - Exercise: '\(exerciseName)', Weight: \(weight), Reps: \(reps)")
        
        // Create PR record first
        let pr = PersonalRecord(
            id: UUID().uuidString,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            oneRepMax: OneRepMax.calculate(weight: weight, reps: reps),
            date: date,
            workoutId: workoutId,
            userId: userId
        )
        
        // Update exerciseRecords
        let exerciseRef = db.collection("users")
            .document(userId)
            .collection("exerciseRecords")
            .document(exerciseName)
        
        try await exerciseRef.setData([
            "maxWeight": weight,
            "reps": reps,
            "oneRepMax": pr.oneRepMax,
            "updatedAt": Timestamp(date: date)
        ], merge: true)
        print("DEBUG: Updated exercise record with new PR data")
        
        // Save PR record
        let prRef = db.collection("users")
            .document(userId)
            .collection("personal_records")
            .document(exerciseName)
        
        let prData = try Firestore.Encoder().encode(pr)
        try await prRef.setData(prData)
        print("DEBUG: Saved PR record to personal_records collection")
        
        // Update the user's PR count
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "totalPRs": FieldValue.increment(Int64(1))
        ])
        print("DEBUG: Updated user's PR count")
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
