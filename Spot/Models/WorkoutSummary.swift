import Foundation
import FirebaseFirestore

extension Array {
    var nilIfEmpty: Self? {
        return isEmpty ? nil : self
    }
}

// Add volume computation extension before the main struct to avoid forward reference issues
extension WorkoutSummary.Exercise.Set {
    var volume: Int {
        return Int(weight * Double(reps))
    }
}

struct WorkoutSummary: Identifiable, Codable, Hashable {
    let id: String  // Non-optional since every workout summary must have an ID
    let userId: String
    let username: String
    let userProfileImageUrl: String?
    let workoutTitle: String
    let workoutNotes: String?
    let date: Date
    let duration: Int
    let totalVolume: Int
    var fistBumps: Int
    var comments: Int
    var exercises: [Exercise]
    var personalRecords: [String: PersonalRecord]?
    var location: String?
    
    init(id: String, userId: String, username: String, userProfileImageUrl: String?, workoutTitle: String, workoutNotes: String?, date: Date, duration: Int, totalVolume: Int, fistBumps: Int = 0, comments: Int = 0, exercises: [Exercise], personalRecords: [String: PersonalRecord]? = nil, location: String? = nil) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userProfileImageUrl = userProfileImageUrl
        self.workoutTitle = workoutTitle
        self.workoutNotes = workoutNotes
        self.date = date
        self.duration = duration
        self.totalVolume = totalVolume
        self.fistBumps = fistBumps
        self.comments = comments
        self.exercises = exercises
        self.personalRecords = personalRecords
        self.location = location
    }
    
    enum CodingKeys: String, CodingKey {
        case id, userId, username, userProfileImageUrl, workoutTitle, workoutNotes
        case date, duration, totalVolume, fistBumps, comments, exercises
        case personalRecords, location
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all non-problematic fields
        id = try container.decode(String.self, forKey: .id)  // Required field
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        userProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .userProfileImageUrl)
        workoutTitle = try container.decode(String.self, forKey: .workoutTitle)
        workoutNotes = try container.decodeIfPresent(String.self, forKey: .workoutNotes)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(Int.self, forKey: .duration)
        totalVolume = try container.decode(Int.self, forKey: .totalVolume)
        fistBumps = try container.decode(Int.self, forKey: .fistBumps)
        comments = try container.decode(Int.self, forKey: .comments)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        
        // Handle personalRecords field
        personalRecords = try? container.decodeIfPresent([String: PersonalRecord].self, forKey: .personalRecords)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(userProfileImageUrl, forKey: .userProfileImageUrl)
        try container.encode(workoutTitle, forKey: .workoutTitle)
        try container.encodeIfPresent(workoutNotes, forKey: .workoutNotes)
        try container.encode(date, forKey: .date)
        try container.encode(duration, forKey: .duration)
        try container.encode(totalVolume, forKey: .totalVolume)
        try container.encode(fistBumps, forKey: .fistBumps)
        try container.encode(comments, forKey: .comments)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(location, forKey: .location)
        
        // Only encode personalRecords if it exists
        try container.encodeIfPresent(personalRecords, forKey: .personalRecords)
    }
    
    struct Exercise: Codable, Identifiable {
        var id: String { exerciseName }
        let exerciseName: String
        let imageUrl: String
        let targetMuscle: String
        var sets: [Set]  // Changed to var since we need to modify it
        var hasPR: Bool
        private var topSet: String?  // For backward compatibility
        
        enum CodingKeys: String, CodingKey {
            case exerciseName
            case imageUrl
            case targetMuscle
            case sets
            case hasPR
            case topSet
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            exerciseName = try container.decode(String.self, forKey: .exerciseName)
            print("Decoding exercise: \(exerciseName)")
            
            imageUrl = try container.decode(String.self, forKey: .imageUrl)
            
            // Try to decode targetMuscle, if not present, use a default value
            if let decodedTargetMuscle = try? container.decode(String.self, forKey: .targetMuscle) {
                targetMuscle = decodedTargetMuscle
            } else {
                // Default to "Unknown" if targetMuscle is not present
                targetMuscle = "Unknown"
            }
            
            // Try to decode sets array
            if let decodedSets = try? container.decode([Set].self, forKey: .sets) {
                sets = decodedSets
            } else {
                // If no sets array, try to create one from topSet
                topSet = try? container.decode(String.self, forKey: .topSet)
                if let topSetString = topSet,
                   let components = topSetString.components(separatedBy: " × ").nilIfEmpty,
                   components.count == 2 {
                    let weightStr = components[0].replacingOccurrences(of: "lbs", with: "").trimmingCharacters(in: .whitespaces)
                    let repsStr = components[1].replacingOccurrences(of: "reps", with: "").trimmingCharacters(in: .whitespaces)
                    
                    if let weight = Double(weightStr),
                       let reps = Int(repsStr) {
                        sets = [Set(weight: weight, reps: reps)]
                    } else {
                        sets = []
                    }
                } else {
                    sets = []
                }
            }
            
            hasPR = try container.decodeIfPresent(Bool.self, forKey: .hasPR) ?? false
            
            print("Decoded \(sets.count) sets")
            sets.forEach { set in
                print("Set: \(set.weight)lbs × \(set.reps) reps")
            }
        }
        
        init(exerciseName: String, imageUrl: String, targetMuscle: String, sets: [Set], hasPR: Bool = false) {
            self.exerciseName = exerciseName
            self.imageUrl = imageUrl
            self.targetMuscle = targetMuscle
            self.sets = sets
            self.hasPR = hasPR
            self.topSet = nil
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exerciseName, forKey: .exerciseName)
            try container.encode(imageUrl, forKey: .imageUrl)
            try container.encode(targetMuscle, forKey: .targetMuscle)
            try container.encode(sets, forKey: .sets)
            try container.encode(hasPR, forKey: .hasPR)
            // Don't encode topSet for new data
        }
        
        struct Set: Codable {
            let weight: Double
            let reps: Int
            var isPR: Bool
            
            enum CodingKeys: String, CodingKey {
                case weight
                case reps
                case isPR
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                weight = try container.decode(Double.self, forKey: .weight)
                reps = try container.decode(Int.self, forKey: .reps)
                isPR = try container.decodeIfPresent(Bool.self, forKey: .isPR) ?? false
            }
            
            init(weight: Double, reps: Int, isPR: Bool = false) {
                self.weight = weight
                self.reps = reps
                self.isPR = isPR
            }
            
            var displayString: String {
                return "\(Int(weight))lbs × \(reps) reps"
            }
        }
    }
    
    // Helper method to get muscle split data
    var muscleSplit: [(muscle: String, sets: Int)] {
        var muscleSetCounts: [String: Int] = [:]
        
        for exercise in exercises {
            muscleSetCounts[exercise.targetMuscle, default: 0] += exercise.sets.count
        }
        
        return muscleSetCounts.sorted { $0.value > $1.value }
            .map { (muscle: $0.key, sets: $0.value) }
    }
    
    static func == (lhs: WorkoutSummary, rhs: WorkoutSummary) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.date == rhs.date
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(userId)
        hasher.combine(date)
    }
}

// Extension to add computed properties that depend on initialized state
extension WorkoutSummary.Exercise {
    var bestSet: Set? {
        if !sets.isEmpty {
            return sets.max(by: { a, b in
                let volumeA = a.weight * Double(a.reps)
                let volumeB = b.weight * Double(b.reps)
                return volumeA < volumeB
            })
        }
        return nil
    }
}

