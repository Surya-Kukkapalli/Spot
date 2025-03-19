import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class WorkoutProgramViewModel: ObservableObject {
    @Published var programs: [WorkoutProgram] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    // MARK: - Program Functions
    
    func createProgram(name: String, description: String?, templates: [WorkoutTemplate]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let program = WorkoutProgram(
            userId: userId,
            name: name,
            description: description,
            workoutTemplates: templates
        )
        
        let encodedProgram = try Firestore.Encoder().encode(program)
        try await db.collection("workout_programs").document(program.id).setData(encodedProgram)
    }
    
    func fetchUserPrograms() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("workout_programs")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            programs = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutProgram.self)
            }
        } catch {
            print("Error fetching programs: \(error)")
        }
    }
    
    // MARK: - Template Functions
    
    func createTemplate(from workout: Workout, description: String?, isPublic: Bool) async throws {
        let template = WorkoutTemplate.fromWorkout(workout, description: description, isPublic: isPublic)
        let encodedTemplate = try Firestore.Encoder().encode(template)
        try await db.collection("workout_templates").document(template.id).setData(encodedTemplate)
    }
    
    func fetchUserTemplates() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("workout_templates")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            templates = snapshot.documents.compactMap { document in
                try? document.data(as: WorkoutTemplate.self)
            }
        } catch {
            print("Error fetching templates: \(error)")
        }
    }
    
    func addTemplateToProgram(_ template: WorkoutTemplate, programId: String) async throws {
        try await db.collection("workout_programs").document(programId).updateData([
            "workoutTemplates": FieldValue.arrayUnion([template])
        ])
        
        // Refresh programs after update
        await fetchUserPrograms()
    }
    
    func removeTemplateFromProgram(_ template: WorkoutTemplate, programId: String) async throws {
        try await db.collection("workout_programs").document(programId).updateData([
            "workoutTemplates": FieldValue.arrayRemove([template])
        ])
        
        // Refresh programs after update
        await fetchUserPrograms()
    }
    
    func deleteProgram(_ program: WorkoutProgram) async throws {
        try await db.collection("workout_programs").document(program.id).delete()
        await fetchUserPrograms()
    }
    
    func deleteTemplate(_ template: WorkoutTemplate) async throws {
        try await db.collection("workout_templates").document(template.id).delete()
        await fetchUserTemplates()
    }
} 