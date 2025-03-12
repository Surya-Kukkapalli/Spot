import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    
    init() {
        userSession = Auth.auth().currentUser
        Task {
            await fetchUser()
        }
    }
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            throw error
        }
    }
    
    func createUser(email: String, password: String, username: String, fullName: String) async throws {
        do {
            print("Starting user creation process")
            
            // Basic validation
            guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
                print("Validation failed: empty fields")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fields are required"])
            }
            
            // Create auth user
            print("Creating auth user")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            
            print("Auth user created with ID: \(result.user.uid)")
            
            // Create user document
            let user = User(
                id: result.user.uid,
                username: username,
                fullName: fullName,
                email: email,
                isInfluencer: false,
                followers: 0,
                following: 0,
                createdAt: Date()
            )
            
            print("Encoding user data")
            let encodedUser = try Firestore.Encoder().encode(user)
            
            print("Saving user to Firestore")
            try await Firestore.firestore().collection("users").document(result.user.uid).setData(encodedUser)
            
            print("User document created successfully")
            self.currentUser = user
            
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
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("DEBUG: Failed to sign out with error \(error.localizedDescription)")
        }
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else { return }
        self.currentUser = try? snapshot.data(as: User.self)
    }
} 