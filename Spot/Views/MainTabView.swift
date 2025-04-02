import SwiftUI

struct MainTabView: View {
    @State private var selectedIndex = 0
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            FeedView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)
            
            VisionView()
                .tabItem {
                    Image(systemName: "eye")
                    Text("Vision")
                }
                .tag(1)
            
            WorkoutView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Workout")
                }
                .tag(2)
            
            CommunityView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Community")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
                .tag(4)
        }
    }
} 
