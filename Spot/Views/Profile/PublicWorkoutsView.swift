import SwiftUI
import FirebaseFirestore

struct PublicWorkoutsView: View {
    let userId: String
    @StateObject private var viewModel = PublicWorkoutsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showCopiedAlert = false
    @State private var selectedTemplate: WorkoutTemplate?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.templates) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        WorkoutTemplateCard(template: template)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Public Workout Templates")
        .sheet(item: $selectedTemplate) { template in
            NavigationStack {
                WorkoutTemplateDetailView(template: template, mode: .copy)
            }
        }
        .task {
            await viewModel.fetchPublicWorkouts(userId: userId)
        }
        .alert("Workout Saved!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can find it in the templates section when logging your next workout.")
        }
    }
}

@MainActor
class PublicWorkoutsViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    private let db = Firestore.firestore()
    
    func fetchPublicWorkouts(userId: String) async {
        do {
            let snapshot = try await db.collection("workout_templates")
                .whereField("userId", isEqualTo: userId)
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            templates = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutTemplate.self)
            }
        } catch {
            print("Error fetching public workouts: \(error)")
        }
    }
    
    func copyWorkoutTemplate(_ template: WorkoutTemplate, for userId: String) async throws {
        var newTemplate = template
        newTemplate.id = UUID().uuidString
        newTemplate.userId = userId
        newTemplate.createdAt = Date()
        newTemplate.updatedAt = Date()
        newTemplate.likes = 0
        newTemplate.usageCount = 0
        
        let encodedTemplate = try Firestore.Encoder().encode(newTemplate)
        try await db.collection("workout_templates").document(newTemplate.id).setData(encodedTemplate)
    }
} 
