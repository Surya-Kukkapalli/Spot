import Foundation

struct OneRepMax {
    static func calculate(weight: Double, reps: Int) -> Double {
        // Brzycki Formula: weight / (1.0278 - 0.0278 × reps)
        let result = Double(weight) / (1.0278 - 0.0278 * Double(reps))
        return round(result * 10) / 10 // Round to 1 decimal place
    }
    
    static func calculateForSet(_ set: WorkoutSummary.Exercise.Set) -> Double {
        return calculate(weight: set.weight, reps: set.reps)
    }
}

// Add extension to Exercise.Set to calculate 1RM
extension WorkoutSummary.Exercise.Set {
    var oneRepMax: Double {
        return OneRepMax.calculate(weight: weight, reps: reps)
    }
}

// Add extension to Exercise for 1RM-related functionality
extension WorkoutSummary.Exercise {
    var bestOneRepMax: Double {
        if let best = bestSet {
            return best.oneRepMax
        }
        return 0
    }
    
    // Helper to determine if a set is a PR based on 1RM
    func isPersonalRecord(_ set: Set) -> Bool {
        let setOneRM = set.oneRepMax
        return sets.allSatisfy { $0.oneRepMax <= setOneRM }
    }
} 