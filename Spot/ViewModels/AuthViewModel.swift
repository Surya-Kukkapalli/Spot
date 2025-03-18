import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    init() {
        self.userSession = Auth.auth().currentUser
        
        Task {
            await fetchUser()
        }
    }
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            print("Attempting to sign in with email: \(email)")
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Sign in successful")
            
            // Wait for user data to be fetched before updating session
            await fetchUser()
            
            await MainActor.run {
                self.userSession = result.user
                print("User session updated")
            }
        } catch {
            print("Sign in error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func createUser(email: String, password: String, username: String, firstName: String, lastName: String) async throws {
        do {
            print("Starting user creation process")
            
            // Basic validation
            guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
                print("Validation failed: empty fields")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fields are required"])
            }
            
            // Create auth user
            print("Creating auth user")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            
            print("Auth user created with ID: \(result.user.uid)")
            
            // Create initial user data
            let userData: [String: Any] = [
                "username": username,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "isInfluencer": false,
                "followers": 0,
                "following": 0,
                "createdAt": Timestamp(date: Date()),
                "workoutsCompleted": 0,
                "totalWorkoutDuration": 0,
                "averageWorkoutDuration": 0,
                "bio": "",
                "profileImageUrl": ""
            ]
            
            print("Saving user data to Firestore")
            try await Firestore.firestore().collection("users").document(result.user.uid).setData(userData)
            
            print("User document created successfully")
            
            // Create local User object
            let user = User(
                id: result.user.uid,
                username: username,
                firstName: firstName,
                lastName: lastName,
                email: email,
                profileImageUrl: nil,
                bio: nil,
                isInfluencer: false,
                followers: 0,
                following: 0,
                createdAt: Date(),
                workoutsCompleted: 0,
                totalWorkoutDuration: 0,
                averageWorkoutDuration: 0,
                personalRecords: nil
            )
            
            await MainActor.run {
                self.currentUser = user
            }
            
        } catch let error as NSError {
            print("Error in createUser: \(error)")
            print("Error domain: \(error.domain)")
            print("Error code: \(error.code)")
            print("Error description: \(error.localizedDescription)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("Underlying error: \(underlyingError)")
            }
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            throw error
        }
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No authenticated user found")
            return
        }
        
        do {
            let docRef = db.collection("users").document(uid)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                print("User document does not exist")
                return
            }
            
            print("Raw user data: \(snapshot.data() ?? [:])")
            
            if let user = try? snapshot.data(as: User.self) {
                await MainActor.run {
                    self.currentUser = user
                    print("User fetched successfully: \(user.username)")
                    print("User bio: \(user.bio ?? "nil")")
                }
            } else {
                print("Failed to decode user data")
                // Try manual decoding to see what's available
                if let data = snapshot.data() {
                    print("Available fields in document:")
                    for (key, value) in data {
                        print("\(key): \(value)")
                    }
                }
            }
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func updateProfile(username: String, firstName: String, lastName: String, bio: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AuthError.userNotFound
        }
        
        let userRef = db.collection("users").document(userId)
        
        // Check if username is already taken (if it's different from current username)
        if let currentUser = currentUser, username != currentUser.username {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            
            if !snapshot.documents.isEmpty {
                throw AuthError.usernameAlreadyExists
            }
        }
        
        // Update user data
        let userData: [String: Any] = [
            "username": username,
            "firstName": firstName,
            "lastName": lastName,
            "bio": bio ?? NSNull()
        ]
        
        try await userRef.updateData(userData)
        
        // Update local user object
        if var updatedUser = currentUser {
            updatedUser.username = username
            updatedUser.firstName = firstName
            updatedUser.lastName = lastName
            updatedUser.bio = bio
            self.currentUser = updatedUser
        }
    }
    
    func migrateExistingUser(_ uid: String) async throws {
        let defaultData: [String: Any] = [
            "username": "user",  // You'll want to set this appropriately
            "firstName": "",     // You'll want to set this appropriately
            "lastName": "",      // You'll want to set this appropriately
            "email": "",        // You'll want to set this appropriately
            "isInfluencer": false,
            "followers": 0,
            "following": 0,
            "createdAt": Timestamp(date: Date()),
            "workoutsCompleted": 0,
            "totalWorkoutDuration": 0,
            "averageWorkoutDuration": 0,
            "profileImageUrl": "",
            "bio": ""
        ]
        
        try await db.collection("users").document(uid).setData(defaultData, merge: true)
    }
    
    @MainActor
    func deleteUserData() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AuthError.userNotFound
        }
        
        // Delete user's workouts
        let workoutDocs = try await db.collection("workout_summaries")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in workoutDocs.documents {
            try await doc.reference.delete()
        }
        
        // Delete user's personal records
        let prDocs = try await db.collection("users")
            .document(userId)
            .collection("personal_records")
            .getDocuments()
        
        for doc in prDocs.documents {
            try await doc.reference.delete()
        }
        
        // Delete user document
        try await db.collection("users").document(userId).delete()
        
        // Clear local state
        self.userSession = nil
        self.currentUser = nil
    }
}

enum AuthError: LocalizedError {
    case usernameAlreadyExists
    case notSignedIn
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .usernameAlreadyExists:
            return "This username is already taken"
        case .notSignedIn:
            return "You must be signed in to perform this action"
        case .userNotFound:
            return "User not found. Please sign in again."
        }
    }
} 