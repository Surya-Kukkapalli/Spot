import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Logo/Title
                Text("Spot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.vertical, 32)
                
                // Input fields
                VStack(spacing: 24) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Sign In Button
                Button {
                    Task {
                        do {
                            try await authViewModel.signIn(withEmail: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding()
                
                // Sign Up Link
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? Create one")
                        .foregroundColor(.blue)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
} 