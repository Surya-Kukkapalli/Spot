import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var bio: String = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Bio")) {
                    TextEditor(text: $bio)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            do {
                                try await authViewModel.updateProfile(bio: bio)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                bio = authViewModel.currentUser?.bio ?? ""
            }
        }
    }
} 