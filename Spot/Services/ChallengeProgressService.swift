import Foundation
import FirebaseFirestore

class ChallengeProgressService {
    private let db = Firestore.firestore()
    private let communityService = CommunityService()
    
    // Calculate progress for a specific workout and challenge
    func calculateProgress(from workout: WorkoutSummary, for challenge: Challenge) async throws -> Double {
        // Skip if workout is outside challenge date range
        guard workout.createdAt >= challenge.startDate && workout.createdAt <= challenge.endDate else {
            return 0
        }
        
        // Calculate progress based on challenge type
        switch challenge.type {
        case .distance:
            return calculateDistanceProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .volume:
            return calculateVolumeProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .duration:
            return calculateDurationProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .count:
            return calculateCountProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
        }
    }
    
    // Track a workout's contribution to active challenges
    func trackWorkoutProgress(_ workout: WorkoutSummary, userId: String) async throws {
        print("DEBUG: Starting to track workout progress")
        print("DEBUG: User ID: \(userId)")
        print("DEBUG: Workout ID: \(workout.id)")
        print("DEBUG: Workout Title: \(workout.workoutTitle)")
        print("DEBUG: Workout Date: \(workout.createdAt)")
        print("DEBUG: Total Volume: \(workout.totalVolume)")
        print("DEBUG: Exercise Count: \(workout.exercises.count)")
        
        // Get active challenges for the user
        let activeChallenges = try await communityService.getActiveChallenges(for: userId)
        print("DEBUG: Found \(activeChallenges.count) active challenges")
        
        for challenge in activeChallenges {
            print("DEBUG: Processing challenge: \(challenge.title)")
            print("DEBUG: Challenge type: \(challenge.type.rawValue)")
            print("DEBUG: Challenge goal: \(challenge.goal) \(challenge.unit)")
            print("DEBUG: Challenge qualifying muscles: \(challenge.qualifyingMuscles)")
            
            // Skip if workout is outside challenge date range
            guard workout.createdAt >= challenge.startDate && workout.createdAt <= challenge.endDate else {
                print("DEBUG: Workout date \(workout.createdAt) is outside challenge range \(challenge.startDate) - \(challenge.endDate)")
                continue
            }
            
            // Calculate progress based on challenge type
            var progress: Double = 0
            
            switch challenge.type {
            case .distance:
                progress = calculateDistanceProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
                print("DEBUG: Calculated distance progress: \(progress)")
                
            case .volume:
                progress = calculateVolumeProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
                print("DEBUG: Calculated volume progress: \(progress)")
                
            case .duration:
                progress = calculateDurationProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
                print("DEBUG: Calculated duration progress: \(progress)")
                
            case .count:
                progress = calculateCountProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
                print("DEBUG: Calculated count progress: \(progress)")
            }
            
            // If there's progress to add, update the challenge
            if progress > 0 {
                print("DEBUG: Updating challenge progress: \(progress)")
                
                // Get current progress
                let currentProgress = challenge.progressForUser(userId)
                print("DEBUG: Current progress: \(currentProgress)")
                
                // Add new progress
                let totalProgress = currentProgress + progress
                print("DEBUG: Total progress after update: \(totalProgress)")
                
                // Update progress in Firestore
                try await communityService.updateChallengeProgress(challenge.id, userId: userId, progress: totalProgress)
                
                // Check if challenge is completed
                if totalProgress >= challenge.goal {
                    print("DEBUG: Challenge completed! Adding to trophy case")
                    try await addChallengeToTrophyCase(challenge, userId: userId)
                }
            } else {
                print("DEBUG: No progress to add for this challenge")
            }
        }
    }
    
    private func calculateDistanceProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        // For now, we'll use a placeholder calculation
        // In a real app, you'd need to track actual distance metrics
        return 0
    }
    
    private func calculateVolumeProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        print("DEBUG: Calculating volume progress")
        print("DEBUG: Qualifying muscles: \(qualifyingMuscles)")
        
        // If no qualifying muscles specified, count all exercises
        if qualifyingMuscles.isEmpty {
            let totalVolume = workout.totalVolume
            print("DEBUG: No qualifying muscles specified, using total volume: \(totalVolume)")
            return Double(totalVolume)
        }
        
        var totalVolume = 0
        let qualifyingMusclesSet = Set(qualifyingMuscles)
        
        for exercise in workout.exercises {
            // Check if target muscle matches qualifying muscles
            let targetMuscle = exercise.targetMuscle
            if qualifyingMusclesSet.contains(targetMuscle) {
                // Calculate volume for this exercise
                let exerciseVolume = exercise.sets.reduce(0) { $0 + $1.volume }
                totalVolume += exerciseVolume
                print("DEBUG: Exercise '\(exercise.exerciseName)' qualifies. Volume: \(exerciseVolume)")
            } else {
                print("DEBUG: Exercise '\(exercise.exerciseName)' does not qualify. Target muscle: \(targetMuscle)")
            }
        }
        
        print("DEBUG: Total qualifying volume: \(totalVolume)")
        return Double(totalVolume)
    }
    
    private func calculateDurationProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        // If any exercise qualifies, count the full duration
        if qualifyingMuscles.isEmpty || workout.exercises.contains(where: { exercise in
            let muscles = Set([exercise.targetMuscle])
            return !Set(qualifyingMuscles).isDisjoint(with: muscles)
        }) {
            return Double(workout.duration)
        }
        return 0
    }
    
    private func calculateCountProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        if qualifyingMuscles.isEmpty {
            return 1 // Count the whole workout
        }
        
        // Check if any exercise qualifies
        return workout.exercises.contains { exercise in
            let muscles = Set([exercise.targetMuscle])
            return !Set(qualifyingMuscles).isDisjoint(with: muscles)
        } ? 1 : 0
    }
    
    private func addChallengeToTrophyCase(_ challenge: Challenge, userId: String) async throws {
        guard let badgeImageUrl = challenge.badgeImageUrl else { return }
        
        let trophy = Trophy(
            id: UUID().uuidString,
            userId: userId,
            title: challenge.title,
            description: challenge.description,
            imageUrl: badgeImageUrl,
            dateEarned: Date(),
            type: .challenge,
            metadata: [
                "challengeId": challenge.id,
                "goal": "\(Int(challenge.goal)) \(challenge.unit)"
            ]
        )
        
        try await db.collection("trophies")
            .document(trophy.id)
            .setData(from: trophy)
    }
}

struct Trophy: Codable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let imageUrl: String
    let dateEarned: Date
    let type: TrophyType
    let metadata: [String: String]
    
    enum TrophyType: String, Codable {
        case challenge
        case achievement
        case milestone
    }
} 
