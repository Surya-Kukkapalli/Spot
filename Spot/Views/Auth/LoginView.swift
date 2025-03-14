import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // App logo/title
                Text("Spot")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.top, 100)
                
                VStack(spacing: 20) {
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
                            try await authViewModel.signIn(withEmail: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert("Error", isPresented: $showAlert) {
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