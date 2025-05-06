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
        case .volume:
            return calculateVolumeProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .time:
            return calculateDurationProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .oneRepMax:
            return calculateOneRepMaxProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
            
        case .personalRecord:
            return calculatePersonalRecordProgress(from: workout, qualifyingMuscles: challenge.qualifyingMuscles)
        }
    }
    
    // Track a workout's contribution to active challenges
    func trackWorkoutProgress(_ workout: WorkoutSummary, userId: String) async throws {
        print("DEBUG: Starting to track workout progress")
        print("DEBUG: User ID: \(userId)")
        print("DEBUG: Workout ID: \(workout.id)")
        
        // Get active challenges for the user
        let activeChallenges = try await communityService.getActiveChallenges(for: userId)
        print("DEBUG: Found \(activeChallenges.count) active challenges")
        
        for challenge in activeChallenges {
            print("DEBUG: Processing challenge: \(challenge.title)")
            print("DEBUG: Challenge type: \(challenge.type.rawValue)")
            print("DEBUG: Challenge scope: \(challenge.scope.rawValue)")
            print("DEBUG: Challenge goal: \(challenge.goal) \(challenge.unit)")
            
            // Skip if workout is outside challenge date range
            guard workout.createdAt >= challenge.startDate && workout.createdAt <= challenge.endDate else {
                print("DEBUG: Workout date \(workout.createdAt) is outside challenge range")
                continue
            }
            
            // Calculate progress based on challenge type
            let progress = try await calculateProgress(from: workout, for: challenge)
            print("DEBUG: Calculated progress: \(progress)")
            
            if progress > 0 {
                print("DEBUG: Updating challenge progress")
                
                // Get current progress
                let currentProgress = challenge.progressForUser(userId)
                print("DEBUG: Current progress: \(currentProgress)")
                
                // For group challenges, add to existing progress
                // For competitive challenges, take max of current and new progress
                let totalProgress: Double
                switch challenge.scope {
                case .group:
                    totalProgress = currentProgress + progress
                    print("DEBUG: Group challenge - Adding progress: \(currentProgress) + \(progress) = \(totalProgress)")
                case .competitive:
                    totalProgress = max(currentProgress, progress)
                    print("DEBUG: Competitive challenge - Taking max: max(\(currentProgress), \(progress)) = \(totalProgress)")
                }
                
                // Update progress in Firestore
                try await communityService.updateChallengeProgress(challenge.id, userId: userId, progress: totalProgress)
                
                // Check if challenge is completed
                let isCompleted: Bool
                switch challenge.scope {
                case .group:
                    isCompleted = challenge.totalProgress >= challenge.goal
                case .competitive:
                    isCompleted = totalProgress >= challenge.goal
                }
                
                if isCompleted {
                    print("DEBUG: Challenge completed! Adding to trophy case")
                    
                    // For group challenges, award trophies to all participants
                    if challenge.scope == .group {
                        for participantId in challenge.participants {
                            try await addChallengeToTrophyCase(challenge, userId: participantId)
                        }
                    } else {
                        try await addChallengeToTrophyCase(challenge, userId: userId)
                    }
                }
            }
        }
        
        print("DEBUG: Completed tracking workout progress for challenges")
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
    
    private func calculateOneRepMaxProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        print("DEBUG: Calculating one rep max progress")
        print("DEBUG: Qualifying muscles: \(qualifyingMuscles)")
        
        // If no qualifying muscles specified, find the highest 1RM across all exercises
        if qualifyingMuscles.isEmpty {
            let maxOneRepMax = workout.exercises.reduce(0.0) { currentMax, exercise in
                let exerciseOneRepMax = exercise.sets.reduce(0.0) { setMax, set in
                    // Using Brzycki formula: 1RM = weight × (36 / (37 - reps))
                    if set.reps > 0 {
                        let oneRepMax = Double(set.weight) * (36.0 / (37.0 - Double(set.reps)))
                        return max(setMax, oneRepMax)
                    }
                    return setMax
                }
                return max(currentMax, exerciseOneRepMax)
            }
            print("DEBUG: No qualifying muscles specified, using highest 1RM: \(maxOneRepMax)")
            return maxOneRepMax
        }
        
        // Find highest 1RM among qualifying exercises
        let qualifyingMusclesSet = Set(qualifyingMuscles)
        var highestOneRepMax = 0.0
        
        for exercise in workout.exercises {
            if qualifyingMusclesSet.contains(exercise.targetMuscle) {
                let exerciseOneRepMax = exercise.sets.reduce(0.0) { setMax, set in
                    if set.reps > 0 {
                        let oneRepMax = Double(set.weight) * (36.0 / (37.0 - Double(set.reps)))
                        return max(setMax, oneRepMax)
                    }
                    return setMax
                }
                highestOneRepMax = max(highestOneRepMax, exerciseOneRepMax)
                print("DEBUG: Exercise '\(exercise.exerciseName)' qualifies. 1RM: \(exerciseOneRepMax)")
            }
        }
        
        print("DEBUG: Highest qualifying 1RM: \(highestOneRepMax)")
        return highestOneRepMax
    }
    
    private func calculatePersonalRecordProgress(from workout: WorkoutSummary, qualifyingMuscles: [String]) -> Double {
        print("DEBUG: Calculating personal record progress")
        print("DEBUG: Qualifying muscles: \(qualifyingMuscles)")
        
        // Count PRs set in this workout that match qualifying muscles
        var prCount = 0
        
        for exercise in workout.exercises {
            // Skip if exercise doesn't match qualifying muscles (when specified)
            if !qualifyingMuscles.isEmpty && !qualifyingMuscles.contains(exercise.targetMuscle) {
                continue
            }
            
            // Find the highest one rep max for this exercise in this workout
            let currentOneRepMax = exercise.sets.reduce(0.0) { maxSoFar, set in
                let setOneRepMax = calculateBrzyckiOneRepMax(weight: Double(set.weight), reps: set.reps)
                return max(maxSoFar, setOneRepMax)
            }
            
            // If this is higher than any previous workout's one rep max for this exercise,
            // count it as a PR
            if currentOneRepMax > 0 {
                Task {
                    if try await isPR(oneRepMax: currentOneRepMax, 
                                    exerciseName: exercise.exerciseName,
                                    targetMuscle: exercise.targetMuscle,
                                    userId: workout.userId,
                                    beforeDate: workout.createdAt) {
                        prCount += 1
                        print("DEBUG: Found PR in exercise '\(exercise.exerciseName)' - 1RM: \(currentOneRepMax)")
                    }
                }
            }
        }
        
        print("DEBUG: Total PRs in workout: \(prCount)")
        return Double(prCount)
    }
    
    private func isPR(oneRepMax: Double, 
                     exerciseName: String,
                     targetMuscle: String,
                     userId: String,
                     beforeDate: Date) async throws -> Bool {
        // Get user's exercise history before this workout
        let snapshot = try await db.collection("workoutSummaries")
            .whereField("userId", isEqualTo: userId)
            .whereField("createdAt", isLessThan: beforeDate)
            .getDocuments()
        
        // Convert to WorkoutSummary objects
        let workouts = try snapshot.documents.compactMap { try $0.data(as: WorkoutSummary.self) }
        
        // Get all sets for this exercise
        let previousSets = workouts.flatMap { workout in
            workout.exercises
                .filter { $0.exerciseName == exerciseName && $0.targetMuscle == targetMuscle }
                .flatMap { $0.sets }
        }
        
        // Calculate previous best one rep max
        let previousBest = previousSets.map { set in
            calculateBrzyckiOneRepMax(weight: Double(set.weight), reps: set.reps)
        }.max() ?? 0
        
        return oneRepMax > previousBest
    }
    
    private func calculateBrzyckiOneRepMax(weight: Double, reps: Int) -> Double {
        // Brzycki formula: 1RM = weight × (36 / (37 - reps))
        // Only calculate if reps are in a reasonable range (1-10 is most accurate)
        if reps > 0 && reps <= 10 {
            return weight * (36.0 / (37.0 - Double(reps)))
        }
        return 0
    }
    
    func addChallengeToTrophyCase(_ challenge: Challenge, userId: String) async throws {
        // Only award trophy if conditions are met
        guard challenge.shouldAwardTrophy(userId: userId) else { return }
        
        // Get user's rank for competitive challenges
        var metadata: [String: String] = [
            "challengeId": challenge.id,
            "goal": "\(Int(challenge.goal)) \(challenge.unit)",
            "scope": challenge.scope.rawValue
        ]
        
        if challenge.scope == .competitive {
            if let rank = challenge.getRank(for: userId) {
                metadata["rank"] = "\(rank)"
                // Only award trophy for top 3 or if user completed the challenge
                guard rank <= 3 || challenge.isCompletedByUser(userId) else { return }
            }
        }
        
        let trophy = Trophy(
            id: UUID().uuidString,
            userId: userId,
            title: challenge.title,
            description: challenge.description,
            imageUrl: challenge.badgeImageUrl ?? "",
            dateEarned: Date(),
            type: .challenge,
            metadata: metadata
        )
        
        try await db.collection("trophies")
            .document(trophy.id)
            .setData(from: trophy)
        
        // Post notification on main thread
        await MainActor.run {
            NotificationCenter.default.post(
                name: .challengeCompleted,
                object: nil,
                userInfo: [
                    "challenge": challenge,
                    "trophy": trophy
                ]
            )
        }
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

extension Notification.Name {
    static let challengeCompleted = Notification.Name("challengeCompleted")
} 
