import SwiftUI

struct ExerciseView: View {
    @State private var exercise: Exercise
    @State private var showAddSet = false
    @ObservedObject var viewModel: WorkoutViewModel
    let exerciseIndex: Int
    
    init(exercise: Exercise, exerciseIndex: Int, viewModel: WorkoutViewModel) {
        _exercise = State(initialValue: exercise)
        self.exerciseIndex = exerciseIndex
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise Header
            HStack {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                Text(exercise.equipment.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Sets List
            ForEach(exercise.sets) { set in
                HStack {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(set.isCompleted ? .green : .gray)
                    
                    Text("\(Int(set.weight))kg × \(set.reps)")
                    
                    Spacer()
                    
                    Text(set.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Add Set Button
            Button {
                showAddSet = true
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showAddSet) {
            AddSetView(
                exerciseIndex: exerciseIndex, viewModel: viewModel
            )
        }
    }
}

#Preview {
    ExerciseView(
        exercise: Exercise(
            id: UUID().uuidString,
            name: "Bench Press",
            sets: [
                ExerciseSet(id: UUID().uuidString, weight: 100, reps: 8, type: .normal, isCompleted: true, restInterval: 90),
                ExerciseSet(id: UUID().uuidString, weight: 100, reps: 8, type: .normal, isCompleted: false, restInterval: 90)
            ],
            equipment: .barbell
        ),
        exerciseIndex: 0,
        viewModel: WorkoutViewModel()
    )
}
