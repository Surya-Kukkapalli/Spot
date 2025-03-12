import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var fullName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    TextField("Full Name", text: $fullName)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            try? await authViewModel.createUser(
                                email: email,
                                password: password,
                                username: username,
                                fullName: fullName
                            )
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || username.isEmpty || fullName.isEmpty)
                }
            }
        }
    }
} 