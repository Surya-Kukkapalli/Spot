import SwiftUI
import PhotosUI // Import the PhotosUI framework
import AVKit

struct VisionView: View {
    // StateObject creates and manages the lifecycle of the ViewModel
    @StateObject private var viewModel = VisionViewModel()

    var body: some View {
        NavigationView { // Use NavigationView for a title bar
            VStack(spacing: 20) {
                // Display status messages from the ViewModel
                Text(viewModel.statusMessage)
                    .padding()

                // Show the selected video (if any) - Placeholder for now
                if let player = viewModel.videoPlayer {
                     VideoPlayer(player: player)
                         .frame(height: 300) // Limit display size
                 } else {
                     Image(systemName: "video.slash.fill") // Placeholder icon
                         .resizable()
                         .scaledToFit()
                         .frame(height: 300)
                         .foregroundColor(.gray)
                 }


                // PhotosPicker for selecting a video
                // It binds the user's selection to the 'selectedVideoItem' in the ViewModel
                PhotosPicker(selection: $viewModel.selectedVideoItem, matching: .videos) {
                    Label("Select Exercise Video", systemImage: "video.badge.plus")
                }
                .disabled(viewModel.isProcessing) // Disable button while processing

                // Button to start the analysis
                Button("Analyze Squat Form") {
                    viewModel.startVideoAnalysis()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedVideoItem == nil || viewModel.isProcessing) // Disable if no video or processing

                // Display feedback results
                if !viewModel.feedbackMessages.isEmpty {
                    List {
                        Section("Form Feedback:") {
                            ForEach(viewModel.feedbackMessages, id: \.self) { message in
                                Text(message)
                            }
                        }
                    }
                }

                Spacer() // Pushes content to the top
            }
            .navigationTitle("Form Analyzer") // Set the title for the view
            .padding() // Add padding around the VStack
        }
    }
}

// Preview provider for SwiftUI Canvas
struct VisionView_Previews: PreviewProvider {
    static var previews: some View {
        VisionView()
    }
}
