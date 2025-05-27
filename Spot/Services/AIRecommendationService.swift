import Foundation

actor AIRecommendationService {
    static let shared = AIRecommendationService()
    private let openAIApiKey: String
    
    private init() {
        // In production, this should be fetched from a secure source
        self.openAIApiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    struct WorkoutRecommendation {
        let exercises: [Exercise]
        let duration: TimeInterval
        let difficulty: String
        let description: String
        let targetMuscleGroups: [String]
    }
    
    struct Exercise {
        let name: String
        let sets: Int
        let reps: String // Can be "12" or "Until failure" or "30 seconds"
        let restBetweenSets: TimeInterval
        let notes: String?
    }
    
    func generateWorkoutPlan(for user: User) async throws -> WorkoutRecommendation {
        guard let fitnessProfile = user.fitnessProfile else {
            throw AIServiceError.missingUserProfile
        }
        
        // Prepare the prompt for the AI model
        let prompt = createWorkoutPrompt(profile: fitnessProfile)
        
        // In a real implementation, this would make an API call to OpenAI or your custom AI service
        // For now, we'll return a mock recommendation
        return createMockRecommendation(for: fitnessProfile)
    }
    
    func analyzeWorkoutProgress(user: User, workoutHistory: [WorkoutSummary]) async throws -> String {
        guard let fitnessProfile = user.fitnessProfile else {
            throw AIServiceError.missingUserProfile
        }
        
        // In a real implementation, this would analyze the workout history and provide insights
        // For now, we'll return a mock analysis
        return createMockAnalysis(profile: fitnessProfile, history: workoutHistory)
    }
    
    private func createWorkoutPrompt(profile: UserFitnessProfile) -> String {
        // Create a detailed prompt for the AI model based on user's profile
        var prompt = "Generate a personalized workout plan for a user with the following characteristics:\n"
        prompt += "Experience Level: \(profile.experienceLevel.rawValue)\n"
        prompt += "Goals: \(profile.goals.map { $0.type.rawValue }.joined(separator: ", "))\n"
        prompt += "Preferred Workout Types: \(profile.preferredWorkoutTypes.map { $0.rawValue }.joined(separator: ", "))\n"
        
        return prompt
    }
    
    private func createMockRecommendation(for profile: UserFitnessProfile) -> WorkoutRecommendation {
        // This is a mock implementation. In production, this would be replaced with actual AI-generated content
        switch profile.experienceLevel {
        case .beginner:
            return WorkoutRecommendation(
                exercises: [
                    Exercise(name: "Bodyweight Squats", sets: 3, reps: "12", restBetweenSets: 60, notes: "Focus on form"),
                    Exercise(name: "Push-ups", sets: 3, reps: "As many as possible", restBetweenSets: 60, notes: "Modify on knees if needed"),
                    Exercise(name: "Walking Lunges", sets: 2, reps: "10 each leg", restBetweenSets: 45, notes: nil)
                ],
                duration: 30 * 60, // 30 minutes
                difficulty: "Beginner",
                description: "A foundational workout focusing on basic movement patterns",
                targetMuscleGroups: ["Legs", "Core", "Chest", "Shoulders"]
            )
        case .intermediate:
            return WorkoutRecommendation(
                exercises: [
                    Exercise(name: "Barbell Squats", sets: 4, reps: "8-10", restBetweenSets: 90, notes: "Warm up with lighter weights"),
                    Exercise(name: "Bench Press", sets: 4, reps: "8-10", restBetweenSets: 90, notes: nil),
                    Exercise(name: "Bent Over Rows", sets: 3, reps: "12", restBetweenSets: 60, notes: nil)
                ],
                duration: 45 * 60, // 45 minutes
                difficulty: "Intermediate",
                description: "A balanced strength training session",
                targetMuscleGroups: ["Legs", "Chest", "Back", "Core"]
            )
        case .advanced:
            return WorkoutRecommendation(
                exercises: [
                    Exercise(name: "Deadlifts", sets: 5, reps: "5", restBetweenSets: 180, notes: "Focus on explosive power"),
                    Exercise(name: "Clean and Press", sets: 4, reps: "6", restBetweenSets: 120, notes: nil),
                    Exercise(name: "Pull-ups", sets: 4, reps: "Until failure", restBetweenSets: 90, notes: nil)
                ],
                duration: 60 * 60, // 60 minutes
                difficulty: "Advanced",
                description: "An intense compound movement focused workout",
                targetMuscleGroups: ["Full Body", "Core", "Back", "Shoulders"]
            )
        }
    }
    
    private func createMockAnalysis(profile: UserFitnessProfile, history: [WorkoutSummary]) -> String {
        // This is a mock implementation. In production, this would be replaced with actual AI-generated analysis
        let totalWorkouts = history.count
        let averageDuration = history.reduce(0.0) { $0 + Double($1.duration) } / Double(max(totalWorkouts, 1))
        
        return """
        Based on your workout history:
        - You've completed \(totalWorkouts) workouts
        - Your average workout duration is \(Int(averageDuration / 60)) minutes
        - You're showing consistent progress in \(profile.preferredWorkoutTypes.first?.rawValue ?? "your workouts")
        
        Recommendations:
        1. Consider increasing workout frequency
        2. Focus on progressive overload
        3. Maintain good form and technique
        """
    }
}

enum AIServiceError: Error {
    case missingUserProfile
    case apiError(String)
} 
