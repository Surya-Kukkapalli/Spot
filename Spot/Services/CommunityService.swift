import Foundation
import FirebaseFirestore

class CommunityService {
    private let db = Firestore.firestore()
    
    // MARK: - Challenges
    
    func getActiveChallenges(for userId: String) async throws -> [Challenge] {
        let snapshot = try await db.collection("challenges")
            .whereField("participants", arrayContains: userId)
            .whereField("endDate", isGreaterThan: Date())
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Challenge.self)
        }
    }
    
    func getAvailableChallenges() async throws -> [Challenge] {
        print("DEBUG: Fetching available challenges")
        let snapshot = try await db.collection("challenges")
            .whereField("endDate", isGreaterThan: Date())
            .getDocuments()
        
        print("DEBUG: Found \(snapshot.documents.count) challenge documents")
        
        let challenges = try snapshot.documents.compactMap { document -> Challenge? in
            do {
                let challenge = try document.data(as: Challenge.self)
                print("DEBUG: Successfully decoded challenge: '\(challenge.title)'")
                print("DEBUG: - ID: \(challenge.id)")
                print("DEBUG: - End Date: \(challenge.endDate)")
                print("DEBUG: - Start Date: \(challenge.startDate)")
                print("DEBUG: - Type: \(challenge.type.rawValue)")
                print("DEBUG: - Goal: \(challenge.goal) \(challenge.unit)")
                print("DEBUG: - Participants: \(challenge.participants.count)")
                print("DEBUG: - Creator ID: \(challenge.creatorId)")
                print("DEBUG: - Qualifying Muscles: \(challenge.qualifyingMuscles)")
                return challenge
            } catch {
                print("DEBUG: Failed to decode challenge document: \(error)")
                return nil
            }
        }
        
        print("DEBUG: Returning \(challenges.count) available challenges")
        return challenges
    }
    
    func createChallenge(_ challenge: Challenge) async throws {
        try await db.collection("challenges")
            .document(challenge.id)
            .setData(from: challenge)
    }
    
    func joinChallenge(_ challengeId: String, userId: String) async throws {
        let ref = db.collection("challenges").document(challengeId)
        
        // First, get the challenge and calculate initial progress
        let snapshot = try await ref.getDocument()
        guard var challenge = try? snapshot.data(as: Challenge.self) else {
            throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
        }
        
        var totalProgress: Double = 0
        
        if !challenge.participants.contains(userId) {
            // Calculate initial progress from past workouts
            let workouts = try await db.collection("workoutSummaries")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: challenge.startDate)
                .whereField("createdAt", isLessThanOrEqualTo: challenge.endDate)
                .getDocuments()
            
            print("DEBUG: Found \(workouts.documents.count) past workouts within challenge date range")
            
            let challengeProgressService = ChallengeProgressService()
            
            for doc in workouts.documents {
                if let workout = try? doc.data(as: WorkoutSummary.self) {
                    let progress = try await challengeProgressService.calculateProgress(from: workout, for: challenge)
                    totalProgress += progress
                    print("DEBUG: Added \(progress) progress from workout \(workout.id)")
                }
            }
            print("DEBUG: Calculated total initial progress: \(totalProgress)")
        }
        
        // Now perform the transaction with the pre-calculated progress
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var challenge = try? snapshot.data(as: Challenge.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
                }
                
                if challenge.participants.contains(userId) {
                    // Remove user if already joined
                    challenge.participants.removeAll { $0 == userId }
                    challenge.completions.removeValue(forKey: userId)
                } else {
                    // Add user if not joined
                    challenge.participants.append(userId)
                    if totalProgress > 0 {
                        challenge.completions[userId] = totalProgress
                        print("DEBUG: Set initial challenge progress to \(totalProgress)")
                    }
                }
                
                try transaction.setData(from: challenge, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func updateChallengeProgress(_ challengeId: String, userId: String, progress: Double) async throws {
        let ref = db.collection("challenges").document(challengeId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var challenge = try? snapshot.data(as: Challenge.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
                }
                
                challenge.completions[userId] = progress
                try transaction.setData(from: challenge, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    // MARK: - Teams
    
    func getUserTeams(for userId: String) async throws -> [Team] {
        let snapshot = try await db.collection("teams")
            .whereField("members", arrayContains: userId)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Team.self)
        }
    }
    
    func getPublicTeams() async throws -> [Team] {
        let snapshot = try await db.collection("teams")
            .whereField("isPrivate", isEqualTo: false)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Team.self)
        }
    }
    
    func createTeam(_ team: Team) async throws {
        guard let teamId = team.id else {
            throw NSError(domain: "CommunityService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Team ID is required"])
        }
        try await db.collection("teams")
            .document(teamId)
            .setData(from: team)
    }
    
    func joinTeam(_ teamId: String, userId: String) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                if !team.members.contains(userId) {
                    team.members.append(userId)
                    try transaction.setData(from: team, forDocument: ref)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func createTeamPost(teamId: String, post: TeamPost) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                team.posts.insert(post, at: 0)
                try transaction.setData(from: team, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func updateTeamGoal(_ teamId: String, goalId: String, progress: Double) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                if let index = team.goals.firstIndex(where: { $0.id == goalId }) {
                    team.goals[index].progress = progress
                    team.goals[index].isCompleted = progress >= team.goals[index].target
                    try transaction.setData(from: team, forDocument: ref)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func addTeamGoal(_ teamId: String, goal: TeamGoal) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                team.goals.append(goal)
                try transaction.setData(from: team, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func removeTeamGoal(_ teamId: String, goalId: String) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                team.goals.removeAll { $0.id == goalId }
                try transaction.setData(from: team, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func leaveTeam(_ teamId: String, userId: String) async throws {
        let ref = db.collection("teams").document(teamId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var team = try? snapshot.data(as: Team.self) else {
                    throw NSError(domain: "CommunityService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team not found"])
                }
                
                // Don't allow creator to leave
                guard team.creatorId != userId else {
                    throw NSError(domain: "CommunityService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Team creator cannot leave the team"])
                }
                
                team.members.removeAll { $0 == userId }
                team.admins.removeAll { $0 == userId }
                try transaction.setData(from: team, forDocument: ref)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    func updateTeam(_ team: Team) async throws {
        guard let teamId = team.id else {
            throw NSError(domain: "CommunityService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Team ID is required"])
        }
        try await db.collection("teams")
            .document(teamId)
            .setData(from: team)
    }
} 
