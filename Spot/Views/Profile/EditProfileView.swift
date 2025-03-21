import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var bio: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Username", text: $username)
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section(header: Text("About")) {
                    TextEditor(text: $bio)
                        .frame(height: 100, alignment: .top)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            do {
                                try await authViewModel.updateProfile(
                                    username: username,
                                    firstName: firstName,
                                    lastName: lastName,
                                    bio: bio
                                )
                                dismiss()
                            } catch {
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    }
                }
            })
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if let user = authViewModel.currentUser {
                    username = user.username
                    let nameParts = (user.name ?? "").split(separator: " ")
                    firstName = String(nameParts.first ?? "")
                    lastName = nameParts.count > 1 ? String(nameParts.dropFirst().joined(separator: " ")) : ""
                    bio = user.bio ?? ""
                }
            }
        }
    }
} 
