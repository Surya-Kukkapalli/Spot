import SwiftUI

struct WelcomeView: View {
    @State private var showSignUp = false
    @State private var showLogin = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome!")
                .font(.system(size: 40, weight: .bold))
                .padding(.top, 60)
            
            Text("You've taken a big step in your fitness journey, and we're here to guide you along the way. Ready?")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Path Illustration
            Image("FitnessJourney") 
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                showSignUp = true
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
//
//            // Login Button
//                HStack(spacing: 4) {
//                    Text("Already a Spotter?")
//                        .foregroundColor(.gray)
//                    
//                    Button {
//                        showLogin = true
//                    } label: {
//                        Text("Login")
//                            .fontWeight(.semibold)
//                            .foregroundColor(.blue)
//                    }
//                }
//                .padding(.bottom, 32)
        }
        //.navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showSignUp) {
            SignUpView()
        }
//        .navigationDestination(isPresented: $showLogin) {
//            LoginView()
//        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
} 
