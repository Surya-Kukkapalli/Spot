import SwiftUI

struct ExerciseSearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var searchText = ""
    @State private var selectedEquipment: Equipment = .barbell
    
    // This would eventually come from a database
    let commonExercises = [
        "Bench Press",
        "Squat",
        "Deadlift",
        "Shoulder Press",
        "Pull-ups",
        "Push-ups"
    ]
    
    var filteredExercises: [String] {
        if searchText.isEmpty {
            return commonExercises
        }
        return commonExercises.filter { $0.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Equipment", selection: $selectedEquipment) {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Text(equipment.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                List(filteredExercises, id: \.self) { exercise in
                    Button(action: {
                        viewModel.addExercise(name: exercise, equipment: selectedEquipment)
                        dismiss()
                    }) {
                        Text(exercise)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 