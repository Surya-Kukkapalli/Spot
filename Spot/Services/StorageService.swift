import Foundation
import FirebaseStorage
import UIKit

class StorageService {
    private let storage = Storage.storage()
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        
        print("DEBUG: Attempting to upload to path: \(path)")
        
        do {
            let _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            print("DEBUG: Successfully uploaded image. Download URL: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("DEBUG: Storage error: \(error)")
            throw error
        }
    }
    
    func uploadChallengeImage(_ image: UIImage, challengeId: String) async throws -> String {
        return try await uploadImage(image, path: "challenges/\(challengeId)/image.jpg")
    }
    
    func uploadTeamImage(_ image: UIImage, teamId: String) async throws -> String {
        return try await uploadImage(image, path: "teams/\(teamId)/image.jpg")
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        return try await uploadImage(image, path: "users/\(userId)/profile_image.jpg")
    }
    
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        try await imageRef.delete()
    }
} 