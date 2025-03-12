import SwiftUI

struct ExerciseSearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var searchText = ""
    @State private var selectedEquipment: Equipment? = nil
    
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
                TextField("Search exercises", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Picker("Equipment", selection: $selectedEquipment) {
                    Text("All").tag(nil as Equipment?)
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Text(equipment.description).tag(equipment as Equipment?)
                    }
                }
                .pickerStyle(.menu)
                
                List(filteredExercises, id: \.self) { exercise in
                    Button(action: {
                        viewModel.addExercise(name: exercise, equipment: selectedEquipment ?? .bodyweight)
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