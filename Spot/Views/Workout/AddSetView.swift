import SwiftUI

struct AddSetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var set: ExerciseSet
    
    var body: some View {
        NavigationView {
            Form {
                Section("Weight") {
                    TextField("Weight (lbs)", value: $set.weight, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                }
                
                Section("Reps") {
                    TextField("Number of reps", value: $set.reps, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }
                
                Section("Type") {
                    Picker("Set Type", selection: $set.type) {
                        Text("Normal").tag(ExerciseSet.SetType.normal)
                        Text("Warm-up").tag(ExerciseSet.SetType.warmup)
                        Text("Drop Set").tag(ExerciseSet.SetType.dropset)
                        Text("Failure").tag(ExerciseSet.SetType.failure)
                    }
                }
                
                Section("Rest Timer") {
                    Stepper(
                        value: $set.restInterval,
                        in: 0...300,
                        step: 15
                    ) {
                        Text("\(Int(set.restInterval)) seconds")
                    }
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddSetView(set: .constant(ExerciseSet(id: UUID().uuidString)))
} 