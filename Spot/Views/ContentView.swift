import SwiftUI

struct ContentView: View {
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                MainTabView()
                    .environmentObject(authViewModel)
            } else {
                OnboardingView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
