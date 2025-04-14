import SwiftUI
import PhotosUI
import AVKit // Import AVKit for AVPlayer

// ObservableObject makes this class publish changes to its properties
// MainActor ensures UI updates happen on the main thread
@MainActor
class VisionViewModel: ObservableObject {

    // Published properties automatically notify the View (VisionView) when they change
    @Published var selectedVideoItem: PhotosPickerItem? {
        // When a new video item is selected...
        didSet {
            // Clear analysis results and generator when video changes
             feedbackItems = []
             poseAnalyzer.cleanupGenerator() // Clean up old generator
             selectedFrameImage = nil
            if let selectedVideoItem {
                loadVideo(from: selectedVideoItem)
            } else {
                videoURL = nil
                videoPlayer = nil
                statusMessage = "Select a video to analyze."
            }
        }
    }

    @Published var videoURL: URL? // URL of the selected video file
    @Published var videoPlayer: AVPlayer? // AVPlayer to display the video
    @Published var statusMessage: String = "Select a video to analyze."
    @Published var isProcessing: Bool = false // Tracks if analysis is running
    // Use the new FeedbackItem struct
    @Published var feedbackItems: [FeedbackItem] = []
    
    // State for displaying the selected frame
    @Published var selectedFrameImage: UIImage? = nil
    @Published var showFrameSheet: Bool = false // To trigger the modal sheet

    // Service responsible for the actual Vision processing and analysis
    // We will define this next (in Step 4 & 5)
    private var poseAnalyzer = PoseAnalyzer()

    // Function called when the "Analyze" button is pressed
    func startVideoAnalysis() {
        guard let url = videoURL else {
            statusMessage = "Error: No video URL found."
            return
        }

        // Prevent starting multiple analyses at once
        guard !isProcessing else { return }

        isProcessing = true
        statusMessage = "Processing video..."
        feedbackItems = [] // Clear previous feedback
        selectedFrameImage = nil // Clear previously shown frame
        
        // Run the analysis in a background task to avoid blocking the UI
        Task {
            do {
                // Call the analyzer service
                let feedback = try await poseAnalyzer.analyzeSquatVideo(url: url)

                // Update UI on the main thread after analysis is done
                self.feedbackItems = feedback
                self.statusMessage = feedback.isEmpty ? "Analysis complete. No issues detected!" : "Analysis complete. Tap feedback for details."

            } catch {
                // Handle errors during analysis
                self.statusMessage = "Error during analysis: \(error.localizedDescription)"
                self.feedbackItems = [FeedbackItem(message: "Analysis failed. Please try again.", frameIndex: nil, timestamp: nil)]
            }
            // Ensure processing state is reset regardless of success or failure
            self.isProcessing = false
            // Note: We don't call cleanupGenerator here yet, as we might need it
            // immediately after analysis to show a frame. Clean up on new video selection.
        }
    }
    
    // Function to load and show a specific frame based on FeedbackItem
    func showFrame(for feedback: FeedbackItem) {
        guard let time = feedback.timestamp else {
            print("No timestamp available for this feedback.")
            return
        }

        // Show loading indicator maybe?
        selectedFrameImage = nil // Clear previous image
        showFrameSheet = true // Trigger the sheet presentation

        Task {
            // Fetch the image using the analyzer's helper function
            let image = await poseAnalyzer.fetchFrameImage(at: time)
            // Update the image on the main thread
             self.selectedFrameImage = image
             if image == nil {
                 print("Failed to load frame image.")
                 // Optionally hide sheet or show placeholder in sheet
                 // self.showFrameSheet = false
             }
        }
    }

    // --- Private Helper ---

    // Loads the video URL from the selected PhotosPickerItem
    private func loadVideo(from item: PhotosPickerItem) {
        statusMessage = "Loading video..."
        // Request the video data asynchronously
        item.loadTransferable(type: VideoItem.self) { result in
            // Switch back to the main thread to update UI properties
            DispatchQueue.main.async {
                switch result {
                case .success(let videoItem?):
                    // Successfully got the URL
                    self.videoURL = videoItem.url
                    // Create an AVPlayer to allow viewing the selected video
                    self.videoPlayer = AVPlayer(url: videoItem.url)
                    self.statusMessage = "Video loaded. Ready to analyze."
                case .success(nil):
                    // Item was empty or couldn't be loaded
                    self.statusMessage = "Error: Could not load video data."
                    self.videoURL = nil
                    self.videoPlayer = nil
                case .failure(let error):
                    // Handle loading errors
                    self.statusMessage = "Error loading video: \(error.localizedDescription)"
                    self.videoURL = nil
                    self.videoPlayer = nil
                }
            }
        }
    }
}

// Helper struct to make loading video URL from PhotosPickerItem easier
struct VideoItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // Defines how to get the data (a file representation) from the picker item
        FileRepresentation(contentType: .movie) { movie in
            // Creates a VideoItem with the temporary file URL provided by the system
            SentTransferredFile(movie.url)
        } importing: { received in
            // Creates a safe copy of the file to a temporary location we control
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            // Returns the VideoItem with the copied URL
            return Self.init(url: copy)
        }
    }
}
