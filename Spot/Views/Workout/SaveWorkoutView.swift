import SwiftUI
import PhotosUI

struct SaveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var workoutTitle: String = ""
    @State private var description: String = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingDiscardAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout title", text: $workoutTitle)
                        .foregroundColor(.secondary)
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
                    PhotosPicker(selection: $selectedItems,
                               matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                            Text("Add a photo / video")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(height: 100)
                        .foregroundColor(description.isEmpty ? .secondary : .primary)
                        .overlay {
                            if description.isEmpty {
                                Text("How did your workout go? Leave some notes here...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                Section {
                    NavigationLink {
                        Text("Visibility settings coming soon")
                    } label: {
                        HStack {
                            Text("Visibility")
                            Spacer()
                            Text("Everyone")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Discard Workout", role: .destructive) {
                        showingDiscardAlert = true
                    }
                }
            }
            .navigationTitle("Save Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveWorkout()
                        }
                    }
                }
            }
            .alert("Discard Workout", isPresented: $showingDiscardAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    Task {
                        await viewModel.discardWorkout()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to discard this workout? This action cannot be undone.")
            }
        }
    }
    
    private func saveWorkout() async {
        viewModel.activeWorkout?.name = workoutTitle
        viewModel.activeWorkout?.notes = description
        try? await viewModel.finishWorkout()
        dismiss()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)min"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    SaveWorkoutView(viewModel: WorkoutViewModel())
} 