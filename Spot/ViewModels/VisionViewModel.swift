// VisionViewModel.swift
// NOW INCLUDES MODIFICATIONS FOR LIVE CAMERA ANALYSIS + VIDEO UPLOAD

import SwiftUI
import PhotosUI
import AVKit
import Combine
import Vision // For orientation if needed

@MainActor
class VisionViewModel: NSObject, ObservableObject {
    
    // MARK: - Analysis Mode
    enum AnalysisMode {
        case videoUpload
        case liveCamera
    }
    @Published var currentMode: AnalysisMode = .videoUpload // Default mode

    // MARK: - Published Properties for Video Upload (Existing)
    @Published var selectedVideoItem: PhotosPickerItem? {
        didSet {
            if currentMode == .videoUpload { // Only process if in video upload mode
                videoLoadDebouncer.send(selectedVideoItem)
            }
        }
    }
    @Published var videoURL: URL?
    @Published var videoPlayer: AVPlayer? // Used for uploaded video preview

    // MARK: - Published Properties for Live Camera
    @Published var isCameraPermissionGranted: Bool = false
    @Published var isLiveSessionRunning: Bool = false
    @Published var livePoseOverlayPoints: [CGPoint?]? // For drawing skeleton in live view
    @Published var currentLiveFeedback: LiveFeedback?
    @Published var repCount: Int = 0
    @Published var liveSummaryFeedbackItems: [FeedbackItem] = [] // For summary after live session
    @Published var isSwitchingCamera: Bool = false // <<<< For loading state
    @Published var analysisCompletedForLive: Bool = false

    // MARK: - Common Published Properties
    @Published var statusMessage: String = "Select mode and video, or start live session."
    @Published var isProcessing: Bool = false // Generic processing flag
    @Published var analysisCompleted: Bool = false // For video upload primarily
    
    // Unified feedback items for display (could be from video or live session summary)
    @Published var displayFeedbackItems: [FeedbackItem] = []

    // Frame Sheet State & Selected Item for Detail (remains useful for both)
    @Published var selectedFeedbackItem: FeedbackItem? = nil
    @Published var selectedFrameImage: UIImage? = nil
    @Published var showFrameSheet: Bool = false {
        didSet {
            if !showFrameSheet {
                selectedFeedbackItem = nil
                selectedFrameImage = nil
            }
        }
    }

    // Error Handling (remains useful)
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false

    // MARK: - Private Properties
    private var poseAnalyzer = PoseAnalyzer()
    private let videoLoadDebouncer = PassthroughSubject<PhotosPickerItem?, Never>() // For video upload
    private var cancellables = Set<AnyCancellable>()

    // --- Camera Specific ---
    let captureSession = AVCaptureSession() // Made public for CameraPreviewView
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.formanalyzer.sessionQueue", qos: .userInitiated)
    private let videoDataOutputQueue = DispatchQueue(label: "com.formanalyzer.videoDataOutputQueue", qos: .userInitiated)
    private var currentCameraPosition: AVCaptureDevice.Position = .front // or .back

    // MARK: - Initialization
    override init() {
        super.init()
        setupDebouncerForVideoUpload()
        checkCameraPermission() // Check permission on init
        analysisCompletedForLive = false
    }

    private func setupDebouncerForVideoUpload() {
        videoLoadDebouncer
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] item in
                guard let self = self, self.currentMode == .videoUpload else { return }
                self.handleVideoItemChange(item: item)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Mode Switching
    func switchMode(to mode: AnalysisMode) {
        if isLiveSessionRunning { stopLiveAnalysis() }
        if isProcessing && currentMode == .videoUpload { /* Maybe cancel? For now, let it finish */ }
        analysisCompletedForLive = false
        
        currentMode = mode
        resetAllState() // Reset states when switching modes
        
        if mode == .liveCamera {
            statusMessage = "Ready for live session. Ensure good lighting."
            if isCameraPermissionGranted {
                setupCaptureSessionIfNeeded()
            } else {
                statusMessage = "Camera permission needed for live mode."
            }
        } else {
            statusMessage = "Select a video to analyze."
        }
    }

    // MARK: - Video Upload Functionality (Adapted from your existing code)
    private func handleVideoItemChange(item: PhotosPickerItem?) {
        guard currentMode == .videoUpload else { return }
        resetVideoUploadState()
        poseAnalyzer.cleanupGenerator() // Cleanup generator from previous video

        guard let selectedItem = item else {
            videoURL = nil
            videoPlayer = nil
            updateStatus("Select a video to analyze.", isError: false)
            return
        }
        updateStatus("Loading video...", isError: false)
        selectedItem.loadTransferable(type: VideoItem.self) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let videoItem?):
                    self.videoURL = videoItem.url
                    self.videoPlayer = AVPlayer(url: videoItem.url) // For preview
                    self.updateStatus("Video loaded. Ready to analyze.", isError: false)
                case .success(nil):
                    self.updateStatus("Error: Could not load video data.", isError: true)
                    self.resetVideoUploadOnlyState()
                case .failure(let error):
                    self.updateStatus("Error loading video: \(error.localizedDescription)", isError: true)
                    self.resetVideoUploadOnlyState()
                }
            }
        }
    }

    func startVideoAnalysis() { // For uploaded video
        guard currentMode == .videoUpload, let url = videoURL else {
            updateStatus("Error: No video URL found for upload analysis.", isError: true)
            return
        }
        guard !isProcessing else { return }

        isProcessing = true
        analysisCompleted = false
        displayFeedbackItems = []
        liveSummaryFeedbackItems = [] // Clear this too
        selectedFeedbackItem = nil
        selectedFrameImage = nil
        errorMessage = nil
        updateStatus("Processing uploaded video...", isError: false)

        videoPlayer?.pause()

        Task {
            var analysisFeedback: [FeedbackItem] = []
            do {
                analysisFeedback = try await poseAnalyzer.analyzeSquatVideo(url: url)
                let populatedFeedback = analysisFeedback.map { item -> FeedbackItem in
                    var mutableItem = item
                    self.populateDetailedFeedback(for: &mutableItem)
                    return mutableItem
                }
                self.displayFeedbackItems = populatedFeedback
                
                // Determine overall status
                let hasIssues = populatedFeedback.contains { $0.type != .positive && $0.type != .detectionQuality }
                let criticalDetectionIssue = populatedFeedback.contains { $0.type == .detectionQuality && $0.message.contains("Could not detect")}

                if criticalDetectionIssue {
                    updateStatus("Video analysis failed: Could not detect poses reliably.", isError: true)
                } else if hasIssues {
                    updateStatus("Video analysis complete. Tap feedback for details.", isError: false)
                } else if !populatedFeedback.isEmpty {
                    updateStatus("Video analysis complete. Good form overall!", isError: false)
                } else {
                    updateStatus("Video analysis finished, but no feedback generated.", isError: true) // Potentially an error if no feedback at all
                }
            } catch {
                let detailedError = (error as NSError).localizedDescription
                updateStatus("Error during video analysis: \(detailedError)", isError: true)
                var errorItem = FeedbackItem(type: .detectionQuality, message: "Analysis failed. \(detailedError)", frameIndex: nil, timestamp: nil)
                populateDetailedFeedback(for: &errorItem)
                self.displayFeedbackItems = [errorItem]
            }
            self.isProcessing = false
            self.analysisCompleted = true
        }
    }

    // MARK: - Live Camera Functionality
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPermissionGranted = true
        case .notDetermined:
            sessionQueue.suspend() // Suspend queue before requesting, resume in completion
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                self.isCameraPermissionGranted = granted
                DispatchQueue.main.async { // Ensure UI updates on main
                     self.statusMessage = granted ? "Camera access granted." : "Camera access denied."
                     if granted && self.currentMode == .liveCamera {
                        self.setupCaptureSessionIfNeeded()
                     }
                }
                self.sessionQueue.resume()
            }
        default:
            isCameraPermissionGranted = false
            statusMessage = "Camera permission denied. Please enable in Settings."
        }
    }

    private var isCaptureSessionConfigured = false
    func setupCaptureSessionIfNeeded() {
        guard isCameraPermissionGranted, !isCaptureSessionConfigured else {
            if !isCameraPermissionGranted {
                DispatchQueue.main.async { self.statusMessage = "Enable camera access in Settings for live mode."}
            }
            return
        }
        
        sessionQueue.async { [weak self] in
            self?.configureCamera(for: self?.currentCameraPosition ?? .front) { success in // Use current or default
                DispatchQueue.main.async {
                    if success {
                        self?.statusMessage = "Camera ready for live session."
                    } else {
                        self?.statusMessage = "Error: Camera setup failed."
                    }
                }
            }
        }
    }
    
    func toggleCamera() {
        guard isCameraPermissionGranted, !isSwitchingCamera else { return } // Prevent multiple toggles
        
        isSwitchingCamera = true // <<<< SET LOADING STATE
        statusMessage = "Switching camera..."
        
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .front) ? .back : .front
        
        // If session is running, stop it before reconfiguring
        let wasRunning = isLiveSessionRunning
        if wasRunning { stopLiveAnalysis(isSwitchingCamera: true) } // Stop session without changing summary
        
        currentCameraPosition = newPosition
        isCaptureSessionConfigured = false // Force reconfiguration with new camera
        
        // Clear old inputs/outputs before setting up new ones
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
            self.captureSession.outputs.forEach { self.captureSession.removeOutput($0) }
            self.captureSession.commitConfiguration()

            // Re-setup capture session (this is already on sessionQueue)
            // The original setupCaptureSessionIfNeeded checks permission and config status.
            // We need to ensure it updates status and isSwitchingCamera upon completion or failure.

            // Directly call the configuration logic for the new camera
            self.configureCamera(for: newPosition) { success in
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false // <<<< CLEAR LOADING STATE
                    if success {
                        self.statusMessage = "Camera switched to \(newPosition == .front ? "front" : "back")."
                        if wasRunning { // Restart session if it was running
                            self.startLiveAnalysis()
                        }
                    } else {
                        self.statusMessage = "Failed to switch camera. Using previous."
                        // Optionally, try to revert to the old camera position or handle error
                        // For simplicity, we'll assume user can try again.
                    }
                }
            }
        }
    }

    // Extracted camera configuration logic to be called by setupCaptureSessionIfNeeded and toggleCamera
    private func configureCamera(for position: AVCaptureDevice.Position, completion: @escaping (Bool) -> Void) {
        // This function should run on self.sessionQueue
        guard isCameraPermissionGranted else {
            print("Camera permission not granted for configuration.")
            completion(false)
            return
        }
        
        captureSession.beginConfiguration()
        // Remove existing inputs before adding a new one
        captureSession.inputs.forEach { captureSession.removeInput($0) }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Failed to get video device for position: \(position)")
            captureSession.commitConfiguration()
            completion(false)
            return
        }
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                self.currentCameraPosition = position // Update current position
            } else {
                print("Cannot add video input to session for position: \(position).")
                captureSession.commitConfiguration()
                completion(false)
                return
            }
        } catch {
            print("Error creating video input for \(position): \(error)")
            captureSession.commitConfiguration()
            completion(false)
            return
        }

        // Output (ensure it's added only once or re-added correctly)
        if !captureSession.outputs.contains(videoDataOutput) { // Add if not already there
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            } else {
                 print("Cannot add video data output to session during configureCamera.")
                 captureSession.commitConfiguration()
                 completion(false)
                 return
            }
        }
        // Always (re)configure output settings
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (position == .front)
            }
        }

        captureSession.commitConfiguration()
        isCaptureSessionConfigured = true
        print("Capture session configured for \(position) camera.")
        completion(true)
    }

    func startLiveAnalysis() {
        guard currentMode == .liveCamera, isCameraPermissionGranted, isCaptureSessionConfigured, !isSwitchingCamera else {
            if isSwitchingCamera { statusMessage = "Please wait, camera is switching." }
            if !isCameraPermissionGranted { updateStatus("Enable camera access in Settings.", isError: true)}
            else if !isCaptureSessionConfigured { updateStatus("Camera not ready. Try again.", isError: true); setupCaptureSessionIfNeeded() }
            return
        }
        guard !isLiveSessionRunning else { return }

        isProcessing = true // Use generic processing flag
        isLiveSessionRunning = true
        analysisCompleted = false // Reset for live session context
        livePoseOverlayPoints = nil
        currentLiveFeedback = nil
        liveSummaryFeedbackItems = [] // Clear summary from previous live session
        displayFeedbackItems = [] // Clear main display
        repCount = 0
        poseAnalyzer.cleanupLiveAnalysisState() // Reset analyzer's internal live state
        self.analysisCompletedForLive = false

        updateStatus("Live session starting...", isError: false)
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            // Update status message
            DispatchQueue.main.async { [weak self] in
                 self?.statusMessage = "Live session active. Reps: 0"
            }
        }
    }

    func stopLiveAnalysis(isSwitchingCamera: Bool = false) {
        guard isLiveSessionRunning else { return }
        
        isProcessing = false
        isLiveSessionRunning = false

        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var finalSummaryItems: [FeedbackItem] = []

                if !isSwitchingCamera {
                    // 1. Process all accumulated feedback items from the live session
                    let allRepFeedbackWithDetails = self.liveSummaryFeedbackItems.map { item -> FeedbackItem in
                        var mutableItem = item
                        self.populateDetailedFeedback(for: &mutableItem) // Ensure details are populated
                        return mutableItem
                    }

                    // 2. Separate constructive items from purely positive ones (excluding .repComplete for summary)
                    let constructiveFeedback = allRepFeedbackWithDetails.filter {
                        $0.type != .positive && $0.type != .repComplete && $0.type != .detectionQuality // Keep detection quality if it's an issue
                    }
                    
                    let positiveRepFeedback = allRepFeedbackWithDetails.filter { $0.type == .positive }
                    let detectionIssues = allRepFeedbackWithDetails.filter { $0.type == .detectionQuality }


                    if self.repCount > 0 {
                        if !constructiveFeedback.isEmpty {
                            // If there's constructive feedback, prioritize showing it.
                            // Also include any specific positive notes that came with those reps.
                            finalSummaryItems.append(contentsOf: constructiveFeedback)
                            // Add positive feedback that might have been for specific parts of reps with issues
                            finalSummaryItems.append(contentsOf: positiveRepFeedback)
                            // Also add any general detection issues if they occurred during reps
                            finalSummaryItems.append(contentsOf: detectionIssues)
                            
                            self.statusMessage = "Session complete! Review your summary. Reps: \(self.repCount)"
                        } else if !positiveRepFeedback.isEmpty {
                            // No constructive feedback, but there were positive notes from reps
                            finalSummaryItems.append(contentsOf: positiveRepFeedback)
                            // Also add any general detection issues if they occurred during reps
                            finalSummaryItems.append(contentsOf: detectionIssues)
                            self.statusMessage = "Great session! Check out your positive feedback. Reps: \(self.repCount)"
                        } else {
                            // Reps were done, but no specific constructive or positive feedback items were generated
                            // (e.g., if analyzeLiveRep only returned .repComplete, or an unexpected empty array)
                            // This is a fallback to ensure something positive is shown.
                            var overallGoodFormItem = FeedbackItem(
                                type: .positive,
                                message: "Excellent work! You completed \(self.repCount) reps with good overall consistency.",
                                frameIndex: nil, timestamp: nil
                            )
                            self.populateDetailedFeedback(for: &overallGoodFormItem)
                            finalSummaryItems.append(overallGoodFormItem)
                             // Also add any general detection issues if they occurred during reps
                            finalSummaryItems.append(contentsOf: detectionIssues)
                            self.statusMessage = "Fantastic job on your \(self.repCount) reps! Summary below."
                        }
                    } else { // No reps completed
                        if !detectionIssues.isEmpty {
                            finalSummaryItems.append(contentsOf: detectionIssues)
                            self.statusMessage = "Session ended. Some issues detected with setup or visibility."
                        } else {
                            var noRepsItem = FeedbackItem(
                                type: .detectionQuality,
                                message: "No full squat repetitions were detected during the session.",
                                frameIndex: nil, timestamp: nil
                            )
                            self.populateDetailedFeedback(for: &noRepsItem)
                            finalSummaryItems.append(noRepsItem)
                            self.statusMessage = "Session ended. No reps recorded."
                        }
                    }
                    // Remove duplicates just in case, prioritizing constructive then positive
                    self.displayFeedbackItems = finalSummaryItems.removingDuplicates()
                    print("displayFeedbackItems count: \(self.displayFeedbackItems.count)")
                    self.analysisCompletedForLive = true
                }
                
                self.currentLiveFeedback = nil // Clear any lingering real-time message
            }
        }
    }


    // MARK: - Common Methods (Feedback Detail, Cleanup)
    func selectFeedbackItemForDetail(_ feedback: FeedbackItem) {
        // This function can remain largely the same as in your existing code,
        // as it's used for showing details of any FeedbackItem.
        // (as in your VisionViewModel.txt source: 308-312)
        // Ensure it works with timestamps from both video and potentially logged live feedback.
        // If live feedback items don't have a specific frame image to show from a video,
        // this might behave differently (e.g., not show an image or show a generic illustration).
        
        guard feedback.timestamp != nil || feedback.type == .detectionQuality || !feedback.detailedExplanation.isNilOrEmpty else {
             print("No timestamp or detailed explanation available for this feedback item. Cannot show details effectively.")
             // For live feedback without a specific image, you might still want to show the text details.
             if !feedback.detailedExplanation.isNilOrEmpty {
                 self.selectedFeedbackItem = feedback
                 self.selectedFrameImage = nil // No specific frame image
                 self.showFrameSheet = true
             }
             return
         }

        self.selectedFeedbackItem = feedback
        self.selectedFrameImage = nil // Clear previous
        self.showFrameSheet = true

        if let ts = feedback.timestamp, currentMode == .videoUpload { // Only fetch from video if in that mode and ts exists
            Task {
                let image = await poseAnalyzer.fetchFrameImage(at: ts)
                if self.selectedFeedbackItem?.id == feedback.id { // Still the same item
                    self.selectedFrameImage = image
                }
                if image == nil { print("Failed to load frame image for time \(ts.seconds ?? -1).") }
            }
        } else if let ts = feedback.timestamp, currentMode == .liveCamera {
            // For live, if you cached the CVPixelBuffer that triggered this feedback, you could convert it to UIImage here.
            // Or, if 'livePoseOverlayPoints' corresponds to this feedback, you might want to render a static image of that pose.
            // For now, we assume live feedback details won't have a specific historical frame image like video.
             print("Showing details for live feedback. Frame image not typically fetched from video generator.")
        }
    }
    
    // cleanupResources now also handles camera session
    // (Adapted from your VisionViewModel.txt source: 312)
    func cleanupResources() {
        print("ViewModel cleaning up resources...")
        if isLiveSessionRunning {
            stopLiveAnalysis()
        }
        sessionQueue.async { [weak self] in // Ensure session stop is on its queue
             if self?.captureSession.isRunning ?? false {
                 self?.captureSession.stopRunning()
             }
             // Remove inputs and outputs to release camera
             self?.captureSession.inputs.forEach { self?.captureSession.removeInput($0) }
             self?.captureSession.outputs.forEach { self?.captureSession.removeOutput($0) }
             self?.isCaptureSessionConfigured = false
             print("Capture session inputs/outputs removed and stopped.")
        }
        
        poseAnalyzer.cleanupGenerator() // For video upload
        poseAnalyzer.cleanupLiveAnalysisState()

        videoPlayer?.pause()
        videoPlayer = nil
        cancellables.forEach { $0.cancel() }
        print("ViewModel resources cleaned up.")
    }


    // MARK: - Private Helper Methods
    private func resetAllState() {
        isProcessing = false
        analysisCompleted = false
        displayFeedbackItems = []
        selectedFeedbackItem = nil
        selectedFrameImage = nil
        errorMessage = nil
        showErrorAlert = false
        analysisCompletedForLive = false
        
        // Video upload specific reset
        resetVideoUploadOnlyState()
        poseAnalyzer.cleanupGenerator()
        
        // Live camera specific reset
        livePoseOverlayPoints = nil
        currentLiveFeedback = nil
        repCount = 0
        liveSummaryFeedbackItems = []
        poseAnalyzer.cleanupLiveAnalysisState()

        // Don't stop/start capture session here, only on mode switch or explicit start/stop
    }
    
    private func resetVideoUploadState() {
        // For when a new video is selected for upload
        isProcessing = false
        analysisCompleted = false
        displayFeedbackItems = []
        selectedFeedbackItem = nil
        selectedFrameImage = nil
        errorMessage = nil
        showErrorAlert = false
    }
    
    private func resetVideoUploadOnlyState() {
        // Only resets the video player parts, not all common states
        videoURL = nil
        videoPlayer?.pause()
        videoPlayer = nil
    }

    private func updateStatus(_ message: String, isError: Bool) {
        self.statusMessage = message
        if isError {
            self.errorMessage = message
            self.showErrorAlert = true
            // For live sessions, an error might not mean 'analysisCompleted' in the same way
            if currentMode == .videoUpload {
                 self.analysisCompleted = true // Mark as "completed" even if with error for video
                 self.isProcessing = false
            } else if currentMode == .liveCamera {
                // For live errors, you might want to stop the session or prompt user
                if isLiveSessionRunning {
                    // stopLiveAnalysis() // Decide if an error should auto-stop
                }
                self.isProcessing = false // Stop general processing indicator
            }
        }
    }
    
    // populateDetailedFeedback remains the same
    // (as in your VisionViewModel.txt source: 321-351)
    private func populateDetailedFeedback(for item: inout FeedbackItem) {
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
            • **Clamshells:** Lie on your side, knees bent, band above knees. Keep feet together and lift top knee against band. (2-3 sets of 15-20 reps)
            • **Lateral Band Walks:** With band above knees or around ankles, take side steps maintaining tension and keeping knees pushed out slightly.
            """
        case .torsoAngle:
             item.detailedExplanation = item.message.contains("Inconsistent") // Original check was "Inconsistent"
                ? "Your torso angle changed significantly during the movement, suggesting potential rounding or arching of the back rather than maintaining a stable, neutral spine."
                : "Your torso leaned forward excessively, particularly at the bottom of the squat. While some lean is normal, too much can shift stress to the lower back."
             item.potentialCauses = "Can be caused by core weakness, poor motor control, limited hip or ankle mobility forcing compensation, or trying to lift too much weight."
             item.correctiveSuggestions = """
             Suggestions:
             • **Core Strengthening:** Incorporate exercises like planks, dead bugs, or bird-dogs to improve core stability.
             • **Focus on Bracing:** Before squatting, take a deep breath and brace your core muscles. Maintain this brace.
             • **Check Mobility:** Ensure adequate hip and ankle mobility.
             • **Tempo Squats:** Squat slowly (e.g., 3 seconds down, 3 seconds up) with lighter weight to focus on maintaining a consistent torso angle.
             """
        case .heelLift:
             item.detailedExplanation = "Your heels lifted off the ground during the squat. Maintaining ground contact is crucial for stability and proper force transfer."
             item.potentialCauses = "Most commonly caused by limited ankle dorsiflexion. Can also be due to stance being too narrow or weight shifting too far forward."
             item.correctiveSuggestions = """
             Suggestions:
             • **Ankle Mobility:** Prioritize ankle stretches like the wall ankle stretch or calf stretches.
             • **Weightlifting Shoes:** Shoes with an elevated heel can help compensate temporarily.
             • **Focus on Mid-foot Pressure:** Consciously think about keeping pressure distributed across your whole foot.
             • **Wider Stance:** Experimenting with a slightly wider stance might help.
             """
        case .ascentRate:
             item.detailedExplanation = "Your hips rose significantly faster than your chest and shoulders as you stood up from the bottom of the squat."
             item.potentialCauses = "Often indicates weak quadriceps relative to posterior chain (glutes/hamstrings), poor core bracing, or incorrect motor pattern."
             item.correctiveSuggestions = """
             Suggestions:
             • **Cue 'Chest Up':** Actively think about driving your chest/shoulders up simultaneously with your hips.
             • **Paused Squats:** Pause for 1-2 seconds at the very bottom of the squat before ascending.
             • **Tempo Squats:** Use a controlled tempo on the way up (e.g., 2-3 seconds).
             • **Strengthen Quads:** Exercises like front squats or leg presses can help.
             """
        case .detectionQuality:
             item.detailedExplanation = "The analysis may be less reliable due to issues detecting body landmarks."
             item.potentialCauses = "Poor lighting, clothing obscuring joints, camera angle cutting off parts of the body, or video quality."
             item.correctiveSuggestions = """
             Suggestions for Better Analysis:
             • Ensure good, even lighting (avoid backlighting).
             • Wear clothing that contrasts with the background and doesn't obscure joints.
             • Film from a side or 45-degree angle (for video), ensuring your full body is visible. For live, ensure full body in frame.
             • Use a stable camera position.
             """
        case .positive:
             item.detailedExplanation = "Based on the analyzed metrics, your squat form appears generally good in the key areas checked."
             item.potentialCauses = "N/A"
             item.correctiveSuggestions = "Keep practicing good form! Consider exploring variations or gradually increasing weight if appropriate for your goals."
        case .liveInstruction:
            item.detailedExplanation = "This is a general instruction provided during your live workout."
            item.potentialCauses = "N/A"
            item.correctiveSuggestions = "Follow the on-screen guidance to improve your form or workout flow."
        case .repComplete:
            item.detailedExplanation = "You've successfully completed a repetition."
            item.potentialCauses = "N/A"
            item.correctiveSuggestions = "Prepare for the next repetition, maintaining good form."
        }
    }
}

// Extension for AVCaptureVideoDataOutputSampleBufferDelegate
extension VisionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentMode == .liveCamera, isLiveSessionRunning,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        Task { // Perform analysis asynchronously off the main thread
            let (liveFb, completedRepFb) = await poseAnalyzer.processLiveFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
            
            // Update UI on the main thread
            await MainActor.run {
                self.livePoseOverlayPoints = liveFb?.posePoints ?? self.poseAnalyzer.getLastDetectedPose() // Update skeleton for drawing
                self.currentLiveFeedback = liveFb // Update live feedback message

                if let repFeedbackItems = completedRepFb {
                    self.repCount = self.poseAnalyzer.getCurrentRepCount() // Update rep count from analyzer
                    self.statusMessage = "Live session active. Reps: \(self.repCount)" // Update status with new rep count
                    
                    // Add to summary and potentially to displayFeedbackItems if desired immediately
                    self.liveSummaryFeedbackItems.append(contentsOf: repFeedbackItems)
                    
                    // Optional: Show an immediate summary of the last rep's major issue
                    if let majorIssue = repFeedbackItems.first(where: { $0.type != .positive && $0.type != .repComplete }) {
                        self.currentLiveFeedback = LiveFeedback(message: "Rep \(self.repCount): \(majorIssue.message)", type: majorIssue.type, posePoints: self.livePoseOverlayPoints)
                    } else if let positive = repFeedbackItems.first(where: {$0.type == .positive}) {
                         self.currentLiveFeedback = LiveFeedback(message: "Rep \(self.repCount): \(positive.message)", type: .positive, posePoints: self.livePoseOverlayPoints)
                    } else if let repDone = repFeedbackItems.first(where: {$0.type == .repComplete}) {
                         self.currentLiveFeedback = LiveFeedback(message: "Rep \(self.repCount): \(repDone.message)", type: .repComplete, posePoints: self.livePoseOverlayPoints)
                    }
                } else if liveFb != nil {
                    // If no rep completed, but there's other live feedback, ensure rep count in status is current
                    if self.statusMessage.contains("Reps:") { // Avoid overwriting "starting" messages
                        self.statusMessage = "Live session active. Reps: \(self.poseAnalyzer.getCurrentRepCount())"
                    }
                }
            }
        }
    }
}


// VideoItem Transferable struct remains the same
// (as in your VisionViewModel.txt source: 351-353)
struct VideoItem: Transferable {
     let url: URL
     static var transferRepresentation: some TransferRepresentation {
         FileRepresentation(contentType: .movie) { movie in
             SentTransferredFile(movie.url)
         } importing: { received in
              let tempDir = URL.temporaryDirectory
              try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
              // Use a unique name based on the received file's name if possible, or UUID
              let fileName = received.file.lastPathComponent
              let copy = tempDir.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
              try? FileManager.default.removeItem(at: copy) // Remove if it somehow exists
              try FileManager.default.copyItem(at: received.file, to: copy)
              return Self.init(url: copy)
          }
      }
  }

// Helper to check for nil or empty string
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// Helper to remove duplicates from FeedbackItem array, keeping the first occurrence
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}
