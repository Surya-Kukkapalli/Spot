import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("unitSystem") private var unitSystem = "imperial" // "imperial" or "metric"
    @State private var showDeleteAccountAlert = false
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    
                    Picker("Unit System", selection: $unitSystem) {
                        Text("Imperial (lbs)").tag("imperial")
                        Text("Metric (kg)").tag("metric")
                    }
                }
                
                Section("Account") {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Label("Edit Profile", systemImage: "person.circle")
                    }
                    
                    NavigationLink {
                        Text("Privacy Policy")
                            .padding()
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                    
                    NavigationLink {
                        Text("Terms of Service")
                            .padding()
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                Section("Support") {
                    NavigationLink {
                        Text("Help Center")
                            .padding()
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "mailto:support@spotapp.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Spot", systemImage: "info.circle")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    try? authViewModel.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        if let user = Auth.auth().currentUser {
                            do {
                                try await user.delete()
                                try await authViewModel.deleteUserData()
                                dismiss()
                            } catch {
                                print("Error deleting account: \(error)")
                            }
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image("AppIcon") // Make sure to add your app icon to assets
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                    
                    Text("Spot")
                        .font(.title)
                        .bold()
                    
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            Section("About") {
                Text("Spot is your personal fitness companion, designed to help you track your workouts, achieve your fitness goals, and connect with other fitness enthusiasts.")
                    .padding(.vertical, 8)
            }
            
            Section("Credits") {
                Link("Developer Website", destination: URL(string: "https://spotapp.com")!)
                Link("Follow us on Twitter", destination: URL(string: "https://twitter.com/spotapp")!)
                Link("Follow us on Instagram", destination: URL(string: "https://instagram.com/spotapp")!)
            }
            
            Section("Legal") {
                NavigationLink("Privacy Policy") {
                    Text("Privacy Policy")
                        .padding()
                }
                NavigationLink("Terms of Service") {
                    Text("Terms of Service")
                        .padding()
                }
                NavigationLink("Licenses") {
                    Text("Third-party Licenses")
                        .padding()
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
} 