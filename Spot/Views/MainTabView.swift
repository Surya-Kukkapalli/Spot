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
            
            DiscoveryView()
                .tabItem {
                    Image(systemName: "community.fill")
                    Text("Community")
                }
                .tag(1)
            
            WorkoutView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Workout")
                }
                .tag(2)
            
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Analytics")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(4)
        }
    }
} 
