import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @StateObject private var signUpData = SignUpData()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAlert = false
    @State private var errorMessage = ""
    @State private var showFitnessProfile = false
    
    private var isFormValid: Bool {
        !signUpData.email.isEmpty &&
        !signUpData.password.isEmpty &&
        !signUpData.username.isEmpty &&
        !signUpData.firstName.isEmpty &&
        !signUpData.lastName.isEmpty &&
        signUpData.password.count >= 6
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Join the community and start your fitness journey")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 20)
            
            // Form Fields
            VStack(spacing: 16) {
                FormField(title: "First Name", text: $signUpData.firstName, icon: "person.fill")
                FormField(title: "Last Name", text: $signUpData.lastName, icon: "person.fill")
                FormField(title: "Username", text: $signUpData.username, icon: "at", autocapitalization: .never)
                FormField(title: "Email", text: $signUpData.email, icon: "envelope.fill", autocapitalization: .never)
                FormField(title: "Password", text: $signUpData.password, icon: "lock.fill", isSecure: true)
                    .overlay(
                        Group {
                            if signUpData.password.count > 0 && signUpData.password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 50)
                            }
                        }
                    )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue Button
            Button {
                if isFormValid {
                    showFitnessProfile = true
                } else {
                    errorMessage = "Please fill in all fields and ensure password is at least 6 characters"
                    showAlert = true
                }
            } label: {
                Text("Continue to Profile Setup")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isFormValid ? Color.red : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isFormValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(false)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showFitnessProfile) {
            NavigationStack {
                FitnessProfileSetupView(signUpData: signUpData)
            }
        }
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .words
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            
            if isSecure {
                SecureField(title, text: $text)
                    .textContentType(.password)
            } else {
                TextField(title, text: $text)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
} 

