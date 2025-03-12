import SwiftUI

struct WorkoutExerciseDetailView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    let exerciseIndex: Int
    
    var body: some View {
        List {
            Section("Sets") {
                ForEach(exercise.sets) { set in
                    Text("\(set.weight) lbs × \(set.reps) reps")
                }
            }
            
            Section {
                Button("Add Set") {
                    // Add set functionality
                }
            }
        }
        .navigationTitle(exercise.name)
    }
} 