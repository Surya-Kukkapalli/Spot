import SwiftUI

struct OnboardingFeature {
    let title: String
    let description: String
    let iconName: String
}

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showLogin = false
    @State private var showSignUp = false
    
    let features = [
        OnboardingFeature(
            title: "AI Form Analysis",
            description: "The only workout app on the market to provide AI form analysis for your exercises",
            iconName: "figure.run"
        ),
        OnboardingFeature(
            title: "Community-Driven",
            description: "Share workouts and progress with friends, tackle goals together, and Spot each other",
            iconName: "person.3.fill"
        ),
        OnboardingFeature(
            title: "Achievement Tracking",
            description: "Stay motivated with achievement-based workout tracking as you push towards your goals",
            iconName: "trophy.fill"
        ),
        OnboardingFeature(
            title: "Smart Workouts",
            description: "Science-based, dynamic workout programs created using our proprietary machine learning models (Coming Soon)",
            iconName: "brain.head.profile"
        ),
        OnboardingFeature(
            title: "Unified Fitness Data",
            description: "Integrate all your favorite fitness apps and visualize your data in one place (Coming Soon)",
            iconName: "chart.bar.fill"
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Logo
                Image("SpotLogo") // Make sure to add this asset
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .padding(.top, 50)

                Text("Spot")
                    .font(.system(size: 45, weight: .medium, design: .rounded))
                    .padding(.top, 15)
                
//                Text("\"The act of supporting another person during exercise, allowing them to achieve more than they could normally\"")
//                    .font(.system(size: 18, weight: .ultraLight, design: .rounded))
//                    .padding(.top, 20)
//                    .padding(.horizontal, 55)
//                    .italic()
//                    .multilineTextAlignment(.center)
                    
                // Feature Carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(systemName: features[index].iconName)
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            
                            Text(features[index].title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(features[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .foregroundColor(.gray)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 300)
                
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<features.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Sign Up Button
                Button {
                    showSignUp = true
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                // Login Button
                HStack(spacing: 4) {
                    Text("Already a Spotter?")
                        .foregroundColor(.gray)
                    
                    Button {
                        showLogin = true
                    } label: {
                        Text("Login")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $showSignUp) {
                WelcomeView()
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
}

#Preview {
    OnboardingView()
} 
