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
    
    func updateProfile(bio: String? = nil, profileImageUrl: String? = nil) async throws {
        guard let uid = userSession?.uid else {
            throw AuthError.notSignedIn
        }
        
        var data: [String: Any] = [:]
        
        if let bio = bio {
            data["bio"] = bio
        }
        
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        let docRef = db.collection("users").document(uid)
        
        do {
            try await docRef.setData(data, merge: true)
            print("Profile updated successfully")
            
            // Fetch updated user data immediately
            let updatedDoc = try await docRef.getDocument()
            if let updatedUser = try? updatedDoc.data(as: User.self) {
                await MainActor.run {
                    self.currentUser = updatedUser
                    print("Current user updated with bio: \(updatedUser.bio ?? "nil")")
                }
            }
        } catch {
            print("Error updating profile: \(error)")
            throw error
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
}

enum AuthError: LocalizedError {
    case usernameAlreadyExists
    case notSignedIn
    
    var errorDescription: String? {
        switch self {
        case .usernameAlreadyExists:
            return "This username is already taken"
        case .notSignedIn:
            return "You must be signed in to perform this action"
        }
    }
} 