import SwiftUI
import PhotosUI
import AVKit
import Combine

@MainActor
class VisionViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var selectedVideoItem: PhotosPickerItem? {
        didSet {
             videoLoadDebouncer.send(selectedVideoItem)
         }
    }
    @Published var videoURL: URL?
    @Published var videoPlayer: AVPlayer?
    @Published var statusMessage: String = "Select a video to analyze."
    @Published var isProcessing: Bool = false
    @Published var analysisCompleted: Bool = false
    @Published var feedbackItems: [FeedbackItem] = []

    // Frame Sheet State & Selected Item for Detail
    @Published var selectedFeedbackItem: FeedbackItem? = nil // Holds the item user tapped
    @Published var selectedFrameImage: UIImage? = nil
    @Published var showFrameSheet: Bool = false {
         // Clear selected item when sheet is dismissed
         didSet {
             if !showFrameSheet {
                 selectedFeedbackItem = nil
                 selectedFrameImage = nil // Also clear image
             }
         }
     }


    // Error Handling
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false


    // MARK: - Private Properties
    private var poseAnalyzer = PoseAnalyzer()
    private let videoLoadDebouncer = PassthroughSubject<PhotosPickerItem?, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupDebouncer()
    }

    private func setupDebouncer() {
        videoLoadDebouncer
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] item in
                self?.handleVideoItemChange(item: item)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func startVideoAnalysis() {
        guard let url = videoURL else {
            updateStatus("Error: No video URL found.", isError: true)
            return
        }
        guard !isProcessing else { return }

        isProcessing = true
        analysisCompleted = false
        feedbackItems = []
        selectedFeedbackItem = nil // Clear selection from previous analysis
        selectedFrameImage = nil
        errorMessage = nil
        updateStatus("Processing video...")

        videoPlayer?.pause()

        Task {
            var analysisFeedback: [FeedbackItem] = []
            do {
                analysisFeedback = try await poseAnalyzer.analyzeSquatVideo(url: url)

                // Populate detailed feedback AFTER analysis
                self.feedbackItems = analysisFeedback.map { item in
                    var mutableItem = item
                    populateDetailedFeedback(for: &mutableItem) // Pass as inout
                    return mutableItem
                }

                // Determine overall status based on populated feedback
                let hasIssues = self.feedbackItems.contains { $0.type != .positive && $0.type != .detectionQuality }
                let criticalDetectionIssue = self.feedbackItems.contains { $0.type == .detectionQuality && $0.message.contains("Could not detect")}

                 if criticalDetectionIssue {
                     updateStatus("Analysis failed: Could not detect poses reliably.", isError: true)
                 } else if hasIssues {
                     updateStatus("Analysis complete. Tap feedback for details.") // Updated message
                 } else if !self.feedbackItems.isEmpty {
                      updateStatus("Analysis complete. Good form overall!")
                 }
                 else {
                      updateStatus("Analysis finished, but no feedback generated.", isError: true)
                 }

            } catch {
                print("Analysis Error: \(error)")
                let detailedError = (error as NSError).localizedDescription
                updateStatus("Error during analysis: \(detailedError)", isError: true)
                var errorItem = FeedbackItem(type: .detectionQuality, message: "Analysis failed. \(detailedError)", frameIndex: nil, timestamp: nil)
                populateDetailedFeedback(for: &errorItem) // Populate details for the error item too
                self.feedbackItems = [errorItem]
            }
            // Final state updates
            self.isProcessing = false
            self.analysisCompleted = true
        }
    }

    // Renamed function for clarity
    func selectFeedbackItemForDetail(_ feedback: FeedbackItem) {
        guard feedback.timestamp != nil else {
             print("No timestamp available for this feedback item. Cannot show frame.")
             // If you want to show details even without a frame:
             self.selectedFeedbackItem = feedback
             self.selectedFrameImage = nil
             self.showFrameSheet = true
             return
         }

        self.selectedFeedbackItem = feedback // Set the selected item
        self.selectedFrameImage = nil // Clear previous image
        self.showFrameSheet = true    // Show the sheet

        // Load the frame image asynchronously
        Task {
            let image = await poseAnalyzer.fetchFrameImage(at: feedback.timestamp!)
            // Ensure the sheet is still for the same item before updating image
             if self.selectedFeedbackItem?.id == feedback.id {
                 self.selectedFrameImage = image
             }
             if image == nil {
                 print("Failed to load frame image for time \(feedback.timestamp!.seconds ?? -1).")
             }
        }
    }


    func cleanupResources() {
        poseAnalyzer.cleanupGenerator()
        videoPlayer?.pause() // Pause before releasing
        videoPlayer = nil
        cancellables.forEach { $0.cancel() } // Cancel subscriptions
        print("ViewModel resources cleaned up.")
    }


    // MARK: - Private Helpers

     private func handleVideoItemChange(item: PhotosPickerItem?) {
         resetAnalysisState()
         poseAnalyzer.cleanupGenerator()

         guard let selectedItem = item else {
             videoURL = nil
             videoPlayer = nil
             updateStatus("Select a video to analyze.")
             return
         }
         updateStatus("Loading video...")
         selectedItem.loadTransferable(type: VideoItem.self) { result in
              DispatchQueue.main.async { [weak self] in
                  guard let self = self else { return }
                  switch result {
                  case .success(let videoItem?):
                      self.videoURL = videoItem.url
                      self.videoPlayer = AVPlayer(url: videoItem.url)
                      self.updateStatus("Video loaded. Ready to analyze.")
                  case .success(nil):
                       self.updateStatus("Error: Could not load video data.", isError: true)
                      self.resetVideoState()
                  case .failure(let error):
                      print("Video Loading Error: \(error)")
                      self.updateStatus("Error loading video: \(error.localizedDescription)", isError: true)
                      self.resetVideoState()
                  }
              }
          }
     }

    private func resetAnalysisState() {
        isProcessing = false
        analysisCompleted = false
        feedbackItems = []
        selectedFeedbackItem = nil // Reset selection
        selectedFrameImage = nil
        errorMessage = nil
        showErrorAlert = false
    }

    private func resetVideoState() {
        videoURL = nil
        videoPlayer?.pause()
        videoPlayer = nil
    }

     private func updateStatus(_ message: String, isError: Bool = false) {
         self.statusMessage = message
         if isError {
             self.errorMessage = message
             self.showErrorAlert = true
              self.analysisCompleted = true
              self.isProcessing = false
         }
     }


    // MARK: - Actionable Feedback Content
    private func populateDetailedFeedback(for item: inout FeedbackItem) {
        // Populate the detailed explanation, causes, and suggestions based on type
        // This is where you store the actionable advice content
        switch item.type {
        case .depth:
            item.detailedExplanation = "Your squat didn't reach full depth, typically defined as the hip crease going below the top of the kneecap."
            item.potentialCauses = "Common causes include limited ankle mobility (dorsiflexion), tight hips, or insufficient strength/control in the deep squat position."
            item.correctiveSuggestions = """
            Suggestions:
            • **Ankle Mobility:** Practice wall ankle stretches (keep heel down, drive knee towards wall) or calf stretches.
            • **Deep Squat Holds:** Hold the bottom of a bodyweight squat (use support if needed) for 20-30 seconds to improve comfort.
            • **Goblet Squats:** Holding a weight at your chest can act as a counterbalance, often making it easier to achieve depth.
            """
        case .kneeValgus:
            item.detailedExplanation = "Your knees moved inward (caved in) during the squat, known as knee valgus. This can place unwanted stress on knee ligaments."
            item.potentialCauses = "Often related to weak outer hip muscles (gluteus medius/minimus), overactive inner thigh muscles (adductors), or sometimes poor ankle stability/mobility."
            item.correctiveSuggestions = """
            Suggestions:
            • **Banded Squats:** Place a light resistance band just above knees. Focus consciously on pushing knees out against the band throughout the squat.
            • **Clamshells:** Lie on your side, knees bent, band above knees. Keep feet together and lift top knee against band. Feel it in your outer hip. (2-3 sets of 15-20 reps)
            • **Lateral Band Walks:** With band above knees or around ankles, take side steps maintaining tension and keeping knees pushed out slightly.
            """
        case .torsoAngle:
             item.detailedExplanation = item.message.contains("Inconsistent")
                ? "Your torso angle changed significantly during the movement, suggesting potential rounding or arching of the back rather than maintaining a stable, neutral spine."
                : "Your torso leaned forward excessively, particularly at the bottom of the squat (\(item.message.components(separatedBy: "(").last ?? "")). While some lean is normal, too much can shift stress to the lower back."
             item.potentialCauses = "Can be caused by core weakness, poor motor control, limited hip or ankle mobility forcing compensation, or trying to lift too much weight."
             item.correctiveSuggestions = """
             Suggestions:
             • **Core Strengthening:** Incorporate exercises like planks, dead bugs, or bird-dogs to improve core stability.
             • **Focus on Bracing:** Before squatting, take a deep breath and brace your core muscles as if preparing for a punch. Maintain this brace throughout the lift.
             • **Check Mobility:** Ensure adequate hip and ankle mobility (see Depth suggestions).
             • **Tempo Squats:** Squat slowly (e.g., 3 seconds down, 3 seconds up) with lighter weight to focus on maintaining a consistent torso angle.
             """
        case .heelLift:
             item.detailedExplanation = "Your heels lifted off the ground during the squat. Maintaining ground contact is crucial for stability and proper force transfer."
             item.potentialCauses = "Most commonly caused by limited ankle dorsiflexion (ability to bend ankle upwards). Can also be due to stance being too narrow or weight shifting too far forward."
             item.correctiveSuggestions = """
             Suggestions:
             • **Ankle Mobility:** Prioritize ankle stretches like the wall ankle stretch or calf stretches (both straight and bent knee).
             • **Weightlifting Shoes:** Shoes with an elevated heel can help compensate temporarily, but addressing mobility is key long-term.
             • **Focus on Mid-foot Pressure:** Consciously think about keeping pressure distributed across your whole foot, especially the heels.
             • **Wider Stance:** Experimenting with a slightly wider stance might help some individuals.
             """
        case .ascentRate:
             item.detailedExplanation = "Your hips rose significantly faster than your chest and shoulders as you stood up from the bottom of the squat."
             item.potentialCauses = "Often indicates weak quadriceps relative to posterior chain (glutes/hamstrings), poor core bracing allowing the hips to 'shoot up', or incorrect motor pattern."
             item.correctiveSuggestions = """
             Suggestions:
             • **Cue 'Chest Up':** Actively think about driving your chest/shoulders up simultaneously with your hips.
             • **Paused Squats:** Pause for 1-2 seconds at the very bottom of the squat before ascending. This can help control the initial drive up.
             • **Tempo Squats:** Use a controlled tempo on the way up (e.g., 2-3 seconds) to prevent rushing out of the bottom.
             • **Strengthen Quads:** Exercises like front squats or leg presses can help address potential quad weakness.
             """
        case .detectionQuality:
             item.detailedExplanation = "The analysis may be less reliable due to issues detecting body landmarks."
             item.potentialCauses = "Poor lighting, clothing obscuring joints, camera angle cutting off parts of the body, or video quality."
             item.correctiveSuggestions = """
             Suggestions for Better Analysis:
             • Ensure good, even lighting (avoid backlighting).
             • Wear clothing that contrasts with the background and doesn't obscure joints.
             • Film from a side or 45-degree angle, ensuring your full body is visible throughout the squat.
             • Use a stable camera position.
             """
        case .positive:
             item.detailedExplanation = "Based on the analyzed metrics, your squat form appears generally good in the key areas checked."
             item.potentialCauses = "N/A"
             item.correctiveSuggestions = "Keep practicing good form! Consider exploring variations or gradually increasing weight if appropriate for your goals."
        }
    }
}

// MARK: - Transferable VideoItem
struct VideoItem: Transferable {
     let url: URL

     static var transferRepresentation: some TransferRepresentation {
         FileRepresentation(contentType: .movie) { movie in
             SentTransferredFile(movie.url)
         } importing: { received in
              let tempDir = URL.temporaryDirectory
              try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
              let copy = tempDir.appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension)")
              try? FileManager.default.removeItem(at: copy)
              try FileManager.default.copyItem(at: received.file, to: copy)
              return Self.init(url: copy)
          }
      }
  }
