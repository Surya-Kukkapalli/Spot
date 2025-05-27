import Foundation

class SignUpData: ObservableObject {
    // Basic Info
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var username: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
    // Fitness Profile
    @Published var weight: Double?
    @Published var height: Double?
    @Published var sex: String = "male"
    @Published var measurementSystem: UserFitnessProfile.MeasurementSystem = .imperial
    
    // Goals and Experience
    @Published var experienceLevel: UserFitnessProfile.ExperienceLevel = .beginner
    @Published var selectedGoalTypes: Set<FitnessGoal.GoalType> = []
    @Published var selectedWorkoutTypes: Set<UserFitnessProfile.WorkoutType> = []
    @Published var goalDescription: String = ""
    
    func createFitnessProfile() -> UserFitnessProfile {
        let weightInKg: Double
        let heightInCm: Double
        
        if measurementSystem == .imperial {
            // Convert lbs to kg
            weightInKg = (weight ?? 0) * 0.453592
            // Convert inches to cm
            heightInCm = (height ?? 0) * 2.54
        } else {
            weightInKg = weight ?? 0
            heightInCm = height ?? 0
        }
        
        let goals = selectedGoalTypes.map { goalType in
            FitnessGoal(type: goalType, description: goalDescription)
        }
        
        return UserFitnessProfile(
            weight: weightInKg,
            height: heightInCm,
            sex: sex,
            goals: goals,
            experienceLevel: experienceLevel,
            preferredWorkoutTypes: Array(selectedWorkoutTypes),
            measurementSystem: measurementSystem
        )
    }
} 
