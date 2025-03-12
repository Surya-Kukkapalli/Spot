import SwiftUI

struct ExerciseView: View {
    @Binding var exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingSetInput = false
    
    var body: some View {
        Section(header: Text(exercise.name)) {
            ForEach(exercise.sets) { set in
                HStack {
                    Text("\(Int(set.weight))kg")
                    Text("×")
                    Text("\(set.reps) reps")
                    Spacer()
                    if set.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Button(action: { showingSetInput = true }) {
                Label("Add Set", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingSetInput) {
            AddSetView(
                exerciseIndex: viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0,
                viewModel: viewModel
            )
        }
    }
} 