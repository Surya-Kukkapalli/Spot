import SwiftUI
import FirebaseFirestore

struct PublicProgramsView: View {
    let userId: String
    @StateObject private var viewModel = PublicProgramsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showCopiedAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.programs) { program in
                    PublicProgramCard(
                        program: program,
                        onCopy: {
                            Task {
                                if let currentUserId = authViewModel.currentUser?.id {
                                    try? await viewModel.copyProgram(program, for: currentUserId)
                                    showCopiedAlert = true
                                }
                            }
                        }
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Public Programs")
        .task {
            await viewModel.fetchPublicPrograms(userId: userId)
        }
        .alert("Program Saved!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can find it in your programs section.")
        }
    }
}

struct PublicProgramCard: View {
    let program: WorkoutProgram
    let onCopy: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(program.name) (\(program.workoutCount))")
                            .font(.headline)
                        if let description = program.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    
                    Menu {
                        Button(action: onCopy) {
                            Label("Save Program", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .foregroundColor(.primary)
            
            if isExpanded {
                ForEach(program.workoutTemplates) { template in
                    NavigationLink(value: template) {
                        WorkoutTemplateCard(template: template)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

@MainActor
class PublicProgramsViewModel: ObservableObject {
    @Published var programs: [WorkoutProgram] = []
    private let db = Firestore.firestore()
    
    func fetchPublicPrograms(userId: String) async {
        do {
            let snapshot = try await db.collection("workout_programs")
                .whereField("userId", isEqualTo: userId)
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            programs = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutProgram.self)
            }
        } catch {
            print("Error fetching public programs: \(error)")
        }
    }
    
    func copyProgram(_ program: WorkoutProgram, for userId: String) async throws {
        var newProgram = program
        newProgram.id = UUID().uuidString
        newProgram.userId = userId
        newProgram.createdAt = Date()
        
        // Create new copies of all workout templates
        var newTemplates: [WorkoutTemplate] = []
        for template in program.workoutTemplates {
            var newTemplate = template
            newTemplate.id = UUID().uuidString
            newTemplate.userId = userId
            newTemplate.createdAt = Date()
            newTemplate.updatedAt = Date()
            newTemplate.likes = 0
            newTemplate.usageCount = 0
            
            // Save the new template
            let encodedTemplate = try Firestore.Encoder().encode(newTemplate)
            try await db.collection("workout_templates").document(newTemplate.id).setData(encodedTemplate)
            
            newTemplates.append(newTemplate)
        }
        
        newProgram.workoutTemplates = newTemplates
        
        let encodedProgram = try Firestore.Encoder().encode(newProgram)
        try await db.collection("workout_programs").document(newProgram.id).setData(encodedProgram)
    }
} 
