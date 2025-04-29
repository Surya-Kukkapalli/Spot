import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Welcome Back!")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Sign in to continue your fitness journey")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 20)
            
            // Form Fields
            VStack(spacing: 16) {
                FormField(title: "Email", text: $email, icon: "envelope.fill", autocapitalization: .never)
                FormField(title: "Password", text: $password, icon: "lock.fill", isSecure: true)
            }
            .padding(.horizontal, 24)
            
            // Forgot Password
            Button {
                // Handle forgot password
            } label: {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
            
            Spacer()
            
            // Sign In Button
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
                    .frame(height: 56)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(false)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
} 