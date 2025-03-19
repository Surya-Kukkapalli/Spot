import SwiftUI

struct NewWorkoutSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @State private var workoutName = ""
    @State private var workoutDescription = ""
    var onStart: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $workoutName)
                    TextField("Description (optional)", text: $workoutDescription)
                }
                
                Section {
                    Text("This will start a new workout session that you can track and optionally save as a template when you're done.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Start") {
                    onStart(workoutName)
                    dismiss()
                }
                .disabled(workoutName.isEmpty)
            )
        }
    }
}

#Preview {
    NewWorkoutSheet { name in
        print("Starting workout: \(name)")
    }
} 