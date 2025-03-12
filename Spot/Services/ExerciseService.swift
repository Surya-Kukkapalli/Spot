import Foundation

class ExerciseService {
    static let shared = ExerciseService()
    
    private let apiKey = "2d64b86a83msh2b852d999ee0ffep1b574ejsn7dee4912ab14"
    private let baseURL = "https://exercisedb.p.rapidapi.com"
    
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
    }
    
    private init() {}
    
    func fetchExercises() async throws -> [ExerciseTemplate] {
        guard let url = URL(string: "\(baseURL)/exercises") else {
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