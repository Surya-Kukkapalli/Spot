import SwiftUI

struct NewWorkoutSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var workoutName = ""
    var onStart: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $workoutName)
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