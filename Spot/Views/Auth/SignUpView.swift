import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .bold()
                .padding(.top, 50)
            
            VStack(spacing: 20) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 32)
            
            Button {
                Task {
                    do {
                        try await viewModel.createUser(
                            email: email,
                            password: password,
                            username: username,
                            firstName: firstName,
                            lastName: lastName
                        )
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            } label: {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
} 

