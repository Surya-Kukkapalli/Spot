import Foundation

struct UserFitnessProfile: Codable {
    var weight: Double?
    var height: Double?
    var sex: String?
    var goals: [FitnessGoal]
    var experienceLevel: ExperienceLevel
    var preferredWorkoutTypes: [WorkoutType]
    var measurementSystem: MeasurementSystem
    
    enum ExperienceLevel: String, Codable {
        case beginner
        case intermediate
        case advanced
    }
    
    enum WorkoutType: String, Codable, CaseIterable {
        case strength = "Strength Training"
        case cardio = "Cardio"
        case hiit = "HIIT"
        case flexibility = "Flexibility"
        case sports = "Sports"
        case crossfit = "CrossFit"
    }
    
    enum MeasurementSystem: String, Codable {
        case metric
        case imperial
    }
}

struct FitnessGoal: Codable, Identifiable {
    let id: String
    var type: GoalType
    var target: Double
    var timeframe: TimeInterval
    var startDate: Date
    var completed: Bool
    var description: String
    
    init(id: String = UUID().uuidString,
         type: GoalType,
         target: Double = 0,
         timeframe: TimeInterval = 12 * 7 * 24 * 60 * 60,
         startDate: Date = Date(),
         completed: Bool = false,
         description: String = "") {
        self.id = id
        self.type = type
        self.target = target
        self.timeframe = timeframe
        self.startDate = startDate
        self.completed = completed
        self.description = description
    }
    
    enum GoalType: String, Codable, CaseIterable {
        case weightLoss = "Weight Loss"
        case muscleGain = "Muscle Gain"
        case endurance = "Endurance"
        case strength = "Strength"
        case flexibility = "Flexibility"
        case generalFitness = "General Fitness"
    }
}

// Add extension to UserFitnessProfile for Firebase compatibility
extension UserFitnessProfile {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "experienceLevel": experienceLevel.rawValue,
            "preferredWorkoutTypes": preferredWorkoutTypes.map { $0.rawValue },
            "measurementSystem": measurementSystem.rawValue
        ]
        
        if let weight = weight { dict["weight"] = weight }
        if let height = height { dict["height"] = height }
        if let sex = sex { dict["sex"] = sex }
        
        dict["goals"] = goals.map { goal in
            [
                "id": goal.id,
                "type": goal.type.rawValue,
                "target": goal.target,
                "timeframe": goal.timeframe,
                "startDate": goal.startDate,
                "completed": goal.completed,
                "description": goal.description
            ]
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> UserFitnessProfile? {
        guard let experienceLevelStr = dict["experienceLevel"] as? String,
              let experienceLevel = ExperienceLevel(rawValue: experienceLevelStr),
              let workoutTypeStrs = dict["preferredWorkoutTypes"] as? [String],
              let measurementSystemStr = dict["measurementSystem"] as? String,
              let measurementSystem = MeasurementSystem(rawValue: measurementSystemStr) else {
            return nil
        }
        
        let preferredWorkoutTypes = workoutTypeStrs.compactMap { WorkoutType(rawValue: $0) }
        
        var goals: [FitnessGoal] = []
        if let goalDicts = dict["goals"] as? [[String: Any]] {
            goals = goalDicts.compactMap { goalDict in
                guard let id = goalDict["id"] as? String,
                      let typeStr = goalDict["type"] as? String,
                      let type = FitnessGoal.GoalType(rawValue: typeStr),
                      let target = goalDict["target"] as? Double,
                      let timeframe = goalDict["timeframe"] as? TimeInterval,
                      let startDate = goalDict["startDate"] as? Date,
                      let completed = goalDict["completed"] as? Bool else {
                    return nil
                }
                
                let description = goalDict["description"] as? String ?? ""
                
                return FitnessGoal(
                    id: id,
                    type: type,
                    target: target,
                    timeframe: timeframe,
                    startDate: startDate,
                    completed: completed,
                    description: description
                )
            }
        }
        
        return UserFitnessProfile(
            weight: dict["weight"] as? Double,
            height: dict["height"] as? Double,
            sex: dict["sex"] as? String,
            goals: goals,
            experienceLevel: experienceLevel,
            preferredWorkoutTypes: preferredWorkoutTypes,
            measurementSystem: measurementSystem
        )
    }
} 