import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
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
                FormField(title: "First Name", text: $firstName, icon: "person.fill")
                FormField(title: "Last Name", text: $lastName, icon: "person.fill")
                FormField(title: "Username", text: $username, icon: "at", autocapitalization: .never)
                FormField(title: "Email", text: $email, icon: "envelope.fill", autocapitalization: .never)
                FormField(title: "Password", text: $password, icon: "lock.fill", isSecure: true)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Sign Up Button
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
                    } catch {
                        errorMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            } label: {
                Text("Create Account")
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

