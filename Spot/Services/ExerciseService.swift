import Foundation

class ExerciseService {
    static let shared = ExerciseService()
    
    private let apiKey = "2d64b86a83msh2b852d999ee0ffep1b574ejsn7dee4912ab14"
    private let baseURL = "https://exercisedb.p.rapidapi.com"
    private var currentOffset = 0
    private let pageSize = 50
    private let recentExercisesKey = "recent_exercises"
    private let maxRecentExercises = 10
    
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
    }
    
    private init() {}
    
    func reset() {
        currentOffset = 0
    }
    
    // Add to recent exercises
    func addToRecent(_ exercise: ExerciseTemplate) {
        var recentExercises = getRecentExercises()
        // Remove if already exists
        recentExercises.removeAll { $0.id == exercise.id }
        // Add to beginning
        recentExercises.insert(exercise, at: 0)
        // Keep only most recent
        if recentExercises.count > maxRecentExercises {
            recentExercises = Array(recentExercises.prefix(maxRecentExercises))
        }
        // Save
        if let encoded = try? JSONEncoder().encode(recentExercises) {
            UserDefaults.standard.set(encoded, forKey: recentExercisesKey)
        }
    }
    
    // Get recent exercises
    func getRecentExercises() -> [ExerciseTemplate] {
        guard let data = UserDefaults.standard.data(forKey: recentExercisesKey),
              let decoded = try? JSONDecoder().decode([ExerciseTemplate].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // Add function to fetch all exercises
    func fetchAllExercises() async throws -> [ExerciseTemplate] {
        guard let url = URL(string: "\(baseURL)/exercises?limit=0") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([ExerciseTemplate].self, from: data)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchExercises(offset: Int? = nil) async throws -> [ExerciseTemplate] {
        let queryOffset = offset ?? currentOffset
        guard let url = URL(string: "\(baseURL)/exercises?offset=\(queryOffset)&limit=\(pageSize)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let exercises = try JSONDecoder().decode([ExerciseTemplate].self, from: data)
            currentOffset += exercises.count
            return exercises
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchExercisesByBodyPart(_ bodyPart: String) async throws -> [ExerciseTemplate] {
        guard let url = URL(string: "\(baseURL)/exercises/bodyPart/\(bodyPart)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([ExerciseTemplate].self, from: data)
        } catch {
            throw APIError.networkError(error)
        }
    }
} 