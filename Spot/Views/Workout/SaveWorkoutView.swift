import SwiftUI
import PhotosUI

struct SaveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @StateObject private var programViewModel = WorkoutProgramViewModel()
    @State private var workoutTitle: String = ""
    @State private var description: String = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingDiscardAlert = false
    @State private var saveAsTemplate = false
    @State private var makeTemplatePublic = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout title", text: $workoutTitle)
                        .foregroundColor(.primary)
                    
                    TextField("Description (optional)", text: $description)
                        .foregroundColor(.primary)
                }
                
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(viewModel.workoutDuration))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(viewModel.calculateVolume()) lbs")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Sets")
                        Spacer()
                        Text("\(viewModel.calculateTotalSets())")
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    HStack {
                        Text("When")
                        Spacer()
                        Text(formatDate(viewModel.workoutStartTime ?? Date()))
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Toggle("Save as Template", isOn: $saveAsTemplate)
                    
                    if saveAsTemplate {
                        Toggle("Make Template Public", isOn: $makeTemplatePublic)
                    }
                }
            }
            .navigationTitle("Save Workout")
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingDiscardAlert = true
                },
                trailing: Button("Save") {
                    Task {
                        if let workout = viewModel.activeWorkout {
                            var workoutToSave = workout
                            workoutToSave.name = workoutTitle
                            workoutToSave.notes = description.isEmpty ? nil : description
                            workoutToSave.exercises = viewModel.exercises // Use the exercises from viewModel
                            
                            try? await viewModel.finishWorkout()
                            
                            if saveAsTemplate {
                                try? await programViewModel.createTemplate(
                                    from: workoutToSave,
                                    description: description.isEmpty ? nil : description,
                                    isPublic: makeTemplatePublic
                                )
                                await programViewModel.fetchUserTemplates() // Refresh templates
                            }
                            
                            dismiss()
                        }
                    }
                }
                .disabled(workoutTitle.isEmpty)
            )
            .alert("Discard Workout?", isPresented: $showingDiscardAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard this workout? This action cannot be undone.")
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SaveWorkoutView(viewModel: WorkoutViewModel())
} 