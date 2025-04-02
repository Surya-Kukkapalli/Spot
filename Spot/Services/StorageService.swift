import Foundation
import FirebaseStorage
import UIKit

class StorageService {
    private let storage = Storage.storage()
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        
        _ = try await imageRef.putDataAsync(imageData, metadata: nil)
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    func uploadChallengeImage(_ image: UIImage, challengeId: String) async throws -> String {
        return try await uploadImage(image, path: "challenges/\(challengeId).jpg")
    }
    
    func uploadTeamImage(_ image: UIImage, teamId: String) async throws -> String {
        return try await uploadImage(image, path: "teams/\(teamId).jpg")
    }
    
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        try await imageRef.delete()
    }
} 