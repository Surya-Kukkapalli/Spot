import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var fullName = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.vertical, 32)
                
                VStack(spacing: 24) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                Button {
                    Task {
                        do {
                            print("Attempting to create user with email: \(email)")
                            try await authViewModel.createUser(
                                email: email,
                                password: password,
                                username: username,
                                fullName: fullName
                            )
                            print("User created successfully")
                            dismiss()
                        } catch {
                            print("Error creating user: \(error)")
                            errorMessage = "\(error.localizedDescription)\n\nDebug info: \(error)"
                            showError = true
                        }
                    }
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
            .navigationBarBackButtonHidden(false)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
} 

