import SwiftUI
import PhotosUI
import AVKit

struct VisionView: View {
    @StateObject private var viewModel = VisionViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(viewModel.statusMessage)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)

                if let player = viewModel.videoPlayer {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                } else { /* Placeholder */ }

                PhotosPicker(selection: $viewModel.selectedVideoItem, matching: .videos) {
                    Label("Select Exercise Video", systemImage: "video.badge.plus")
                }
                .disabled(viewModel.isProcessing)

                Button("Analyze Squat Form") {
                    viewModel.startVideoAnalysis()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedVideoItem == nil || viewModel.isProcessing)

                // Display feedback results - now using feedbackItems
                if !viewModel.feedbackItems.isEmpty {
                    List {
                        Section("Form Feedback:") {
                            // Iterate over FeedbackItem, identifiable by its id
                            ForEach(viewModel.feedbackItems, id: \.id) { item in
                                HStack {
                                    Text(item.message)
                                    Spacer()
                                    // Show chevron if frame is available
                                    if item.timestamp != nil {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .contentShape(Rectangle()) // Make entire row tappable
                                .onTapGesture {
                                    // Only trigger if there's a timestamp
                                    if item.timestamp != nil {
                                        print("Tapped feedback: \(item.message)")
                                        viewModel.showFrame(for: item)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Form Analyzer")
            .padding()
            // Add the sheet modifier to present the frame
            .sheet(isPresented: $viewModel.showFrameSheet) {
                // Content of the sheet
                VStack {
                    Text("Relevant Frame")
                        .font(.headline)
                        .padding()

                    if let image = viewModel.selectedFrameImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        // Show loading indicator while frame loads
                        ProgressView()
                            .padding()
                        Text("Loading Frame...")
                    }
                    Spacer()
                    Button("Dismiss") {
                        viewModel.showFrameSheet = false
                    }
                    .padding()
                }
            }
        }
    }
}

// Preview provider for SwiftUI Canvas
struct VisionView_Previews: PreviewProvider {
    static var previews: some View {
        VisionView()
    }
}
