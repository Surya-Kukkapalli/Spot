import SwiftUI

struct AddSetView: View {
    let exerciseIndex: Int
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var setType: ExerciseSet.SetType = .normal
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                    
                    Stepper("Reps: \(reps)", value: $reps, in: 0...100)
                    
                    Picker("Set Type", selection: $setType) {
                        Text("Normal").tag(ExerciseSet.SetType.normal)
                        Text("Warm Up").tag(ExerciseSet.SetType.warmup)
                        Text("Drop Set").tag(ExerciseSet.SetType.dropset)
                        Text("Failure").tag(ExerciseSet.SetType.failure)
                    }
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addSet(to: exerciseIndex, weight: weight, reps: reps, type: setType)
                        dismiss()
                    }
                }
            }
        }
    }
} 