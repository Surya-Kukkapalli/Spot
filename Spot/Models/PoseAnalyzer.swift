// PoseAnalyzer.swift
// NOW INCLUDES MODIFICATIONS FOR REAL-TIME ANALYSIS SUPPORT

import AVFoundation
import Vision
import UIKit
import CoreImage

// FeedbackItem struct remains largely the same
// (as in your provided PoseAnalyzer.txt source: 1-6)
struct FeedbackItem: Identifiable, Hashable {
    enum FeedbackType: String {
        case depth = "Depth"
        case kneeValgus = "Knee Position"
        case torsoAngle = "Torso/Back Posture"
        case heelLift = "Heel Position"
        case ascentRate = "Ascent Rate"
        case detectionQuality = "Detection Quality"
        case positive = "Good Form"
        // Potentially add for live feedback
        case liveInstruction = "Instruction"
        case repComplete = "Repetition"
    }

    let id = UUID()
    let type: FeedbackType
    let message: String
    let frameIndex: Int? // For video analysis
    let timestamp: CMTime? // For video analysis & potentially live frame reference

    var detailedExplanation: String? = nil
    var potentialCauses: String? = nil
    var correctiveSuggestions: String? = nil

    // Timestamp for live feedback, if different from video analysis timestamp
    // let liveTimestamp: Date? // Alternative for live feedback logging

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: FeedbackItem, rhs: FeedbackItem) -> Bool {
        lhs.id == rhs.id
    }
}

// Struct for immediate, concise live feedback
struct LiveFeedback {
    let id = UUID() // For potential list updates if displaying a stream of live feedback
    let message: String
    let type: FeedbackItem.FeedbackType
    let posePoints: [CGPoint?]? // Optionally pass points for drawing
}

// --- Squat State for Live Analysis ---
enum SquatPhase {
    case idle // Waiting for squat to start
    case descending
    case bottom
    case ascending
    case completedRep // Briefly after a rep is done
}

class PoseAnalyzer {

    private var imageGenerator: AVAssetImageGenerator? // For uploaded video frame fetching
    private var ciContext = CIContext()

    private let neededJoints: [VNHumanBodyPoseObservation.JointName] = [
        .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftShoulder, .rightShoulder
    ]
    // Joint indices (as in your provided PoseAnalyzer.txt source: 7-8)
    private let rootIdx = 0, lHipIdx = 1, rHipIdx = 2, lKneeIdx = 3, rKneeIdx = 4
    private let lAnkleIdx = 5, rAnkleIdx = 6, lShoulderIdx = 7, rShoulderIdx = 8

    // --- Properties for Live Analysis State ---
    private var currentSquatPhase: SquatPhase = .idle
    private var repCount: Int = 0
    private var currentRepPoses: [[CGPoint?]] = [] // Store poses for the current live rep
    private var currentRepTimestamps: [CMTime] = []
    private var lastPose: [CGPoint?]? // To store the most recent pose for drawing

    private var peakHipHeight: CGFloat? // Track peak hip height to detect start of descent
    private var valleyHipHeight: CGFloat? // Track lowest hip height for bottom detection
    private var startOfDescentTimestamp: CMTime?

    // Thresholds for live state changes (these need tuning)
    private let hipMovementThreshold: CGFloat = 0.03 // Normalized Y movement to trigger phase change
    private let minRepDuration: Double = 0.8 // Minimum seconds for a rep to be valid

    // MARK: - Video Upload Analysis (Existing Functionality)
    // analyzeSquatVideo(url: URL) -> [FeedbackItem]
    // (Largely as in your provided PoseAnalyzer.txt source: 9-42, with minor adjustments if any)
    // This function remains the primary entry point for uploaded video analysis.
    func analyzeSquatVideo(url: URL) async throws -> [FeedbackItem] {
        print("Starting analysis for video: \(url.lastPathComponent)")
        cleanupLiveAnalysisState() // Ensure live state is reset

        let asset = AVURLAsset(url: url)
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.appliesPreferredTrackTransform = true
        imageGenerator?.requestedTimeToleranceBefore = .zero
        imageGenerator?.requestedTimeToleranceAfter = .zero

        let frameData = try await readVideoFrames(url: url)

        guard !frameData.pixelBuffers.isEmpty else {
            imageGenerator = nil
            print("Analysis stopped: No frames read from video.")
            return [FeedbackItem(type: .detectionQuality, message: "Could not read any frames from the video.", frameIndex: nil, timestamp: nil)]
        }
        print("Read \(frameData.pixelBuffers.count) frames. Starting pose estimation...")

        var allFramePoses: [[CGPoint?]] = []
        for (index, frame) in frameData.pixelBuffers.enumerated() {
            if index % 10 == 0 || index == frameData.pixelBuffers.count - 1 {
                print("  Processing frame \(index + 1)/\(frameData.pixelBuffers.count)...")
            }
            do {
                let posePoints = try await performPoseEstimation(on: frame, isLive: false)
                allFramePoses.append(posePoints)
            } catch {
                print("  Error during pose estimation for frame \(index): \(error.localizedDescription). Skipping frame.")
                allFramePoses.append(Array(repeating: nil, count: neededJoints.count))
            }
        }

        print("Finished processing frames. Checking detection quality...")
        let qualityCheckFeedback = checkPoseDetectionQuality(allFramePoses: allFramePoses, totalFrames: frameData.pixelBuffers.count)
        if let criticalFeedback = qualityCheckFeedback.first(where: { $0.message.contains("Could not detect key leg joints consistently") }) {
            imageGenerator = nil
            return [criticalFeedback]
        }
        
        print("Pose data sufficient. Proceeding to analyzeSquatForm for video.")
        let analysisFeedback = analyzeFullSquatSequence(poses: allFramePoses, frameData: frameData)
        return qualityCheckFeedback + analysisFeedback
    }

    // fetchFrameImage remains the same (as in your provided PoseAnalyzer.txt source: 19-20)
    func fetchFrameImage(at time: CMTime) async -> UIImage? {
         guard let generator = imageGenerator else { return nil }
         do {
             let cgImage = try await generator.copyCGImage(at: time, actualTime: nil)
             return UIImage(cgImage: cgImage)
         } catch {
             print("Error generating frame image at time \(CMTimeGetSeconds(time)): \(error)")
             return nil
         }
     }

    // cleanupGenerator remains the same (as in your provided PoseAnalyzer.txt source: 20)
    func cleanupGenerator() {
        imageGenerator = nil
        print("Image generator cleaned up for video analysis.")
    }

    // readVideoFrames remains the same (as in your provided PoseAnalyzer.txt source: 21-28)
    private func readVideoFrames(url: URL) async throws -> FrameData {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "PoseAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        let videoSize = try await track.load(.naturalSize)
        let frameRate = try await track.load(.nominalFrameRate)
        let frameDuration = frameRate > 0 ? CMTime(value: 1, timescale: CMTimeScale(frameRate)) : nil

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)

        guard reader.canAdd(readerOutput) else {
             throw NSError(domain: "PoseAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add reader output"])
        }
        reader.add(readerOutput)
        guard reader.startReading() else {
             throw NSError(domain: "PoseAnalyzer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start reading video"])
         }

        var pixelBuffers: [CVPixelBuffer] = []
        var timestamps: [CMTime] = []
        while reader.status == .reading {
            if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
               let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                pixelBuffers.append(pixelBuffer)
                timestamps.append(timestamp)
                CMSampleBufferInvalidate(sampleBuffer)
            } else if reader.status == .completed {
                 break
            } else if reader.status == .failed {
                print("Reader failed with error: \(reader.error?.localizedDescription ?? "Unknown error")")
                throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
            }
             try? await Task.sleep(nanoseconds: 1_000)
        }
        
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
        }
        print("Successfully read \(pixelBuffers.count) frames.")
        return FrameData(pixelBuffers: pixelBuffers, timestamps: timestamps, videoSize: videoSize, frameDuration: frameDuration)
    }
    
    // performPoseEstimation now has a flag for live mode to update lastPose
    // (Logic largely as in your provided PoseAnalyzer.txt source: 29-32)
    private func performPoseEstimation(on pixelBuffer: CVPixelBuffer, isLive: Bool) async throws -> [CGPoint?] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        try handler.perform([request])

        guard let observation = request.results?.first else {
            if isLive { self.lastPose = Array(repeating: nil, count: neededJoints.count) }
            return Array(repeating: nil, count: neededJoints.count)
        }

        let allRecognizedPoints = try observation.recognizedPoints(.all)
        var framePoints: [CGPoint?] = []
        for jointName in neededJoints {
            if let point = allRecognizedPoints[jointName], point.confidence > 0.1 {
                framePoints.append(point.location)
            } else {
                framePoints.append(nil)
            }
        }
        if isLive { self.lastPose = framePoints } // Store for drawing
        return framePoints
    }
    
    // Renamed analyzeSquatForm to analyzeFullSquatSequence for clarity
    // This is for the uploaded video analysis
    // (Logic as in your provided PoseAnalyzer.txt source: 33-42)
    private func analyzeFullSquatSequence(poses: [[CGPoint?]], frameData: FrameData) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []
        let timestamps = frameData.timestamps
        let frameCount = poses.count

        guard frameCount > 5 else {
             return [FeedbackItem(type: .detectionQuality, message: "Video too short or too few poses detected for meaningful analysis.", frameIndex: nil, timestamp: nil)]
        }
        
        var minAvgHipY: CGFloat = 1.0
        var bottomFrameIndex: Int? = nil

        for (index, framePoses) in poses.enumerated() {
            let leftHipY = framePoses[lHipIdx]?.y
            let rightHipY = framePoses[rHipIdx]?.y
            var currentAvgHipY: CGFloat?
            if let lY = leftHipY, let rY = rightHipY { currentAvgHipY = (lY + rY) / 2.0 }
            else { currentAvgHipY = leftHipY ?? rightHipY }

            if let avgY = currentAvgHipY {
                if avgY < minAvgHipY {
                    minAvgHipY = avgY
                    bottomFrameIndex = index
                }
            }
        }

        guard let bottomIdx = bottomFrameIndex else {
            return [FeedbackItem(type: .detectionQuality, message: "Could not determine the bottom of the squat.", frameIndex: nil, timestamp: nil)]
        }

        let depthFeedback = checkSquatDepth(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps, isLive: false, livePose: nil)
        feedback.append(contentsOf: depthFeedback)
        let kneeValgusFeedback = checkKneeValgus(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps, isLive: false, livePose: nil)
        feedback.append(contentsOf: kneeValgusFeedback)
        let torsoFeedback = checkTorsoAngle(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps, isLive: false, livePose: nil)
        feedback.append(contentsOf: torsoFeedback)
        let heelLiftFeedback = checkHeelLift(poses: poses, timestamps: timestamps, isLive: false, livePose: nil)
        feedback.append(contentsOf: heelLiftFeedback)
        let ascentFeedback = checkAscentRate(poses: poses, bottomFrameIndex: bottomIdx, frameDuration: frameData.frameDuration, timestamps: timestamps)
        feedback.append(contentsOf: ascentFeedback)

        let negativeFeedbackCount = feedback.filter { $0.type != .positive && $0.type != .detectionQuality }.count
        if negativeFeedbackCount == 0 && !feedback.contains(where: { $0.type == .detectionQuality && $0.message.contains("Could not detect") }) {
             feedback.append(FeedbackItem(type: .positive, message: "Good overall squat form detected in video!", frameIndex: bottomIdx, timestamp: timestamps[safe: bottomIdx]))
        }
        return feedback
    }
    
    // (Specific form check functions like checkSquatDepth, checkKneeValgus, etc. from source: 43-86
    //  will be MODIFIED to accept an optional single 'livePose' and an 'isLive' flag,
    //  or be called with 'poses' containing data for the current live rep)

    // --- Helper for detection quality used by video upload ---
    private func checkPoseDetectionQuality(allFramePoses: [[CGPoint?]], totalFrames: Int) -> [FeedbackItem] {
        guard totalFrames > 0 else { return [] }
        let framesWithSufficientPoses = allFramePoses.filter { frame in
            (frame[lHipIdx] != nil && frame[lKneeIdx] != nil && frame[lAnkleIdx] != nil) ||
            (frame[rHipIdx] != nil && frame[rKneeIdx] != nil && frame[rAnkleIdx] != nil)
        }.count

        var feedback: [FeedbackItem] = []
        if framesWithSufficientPoses == 0 {
            feedback.append(FeedbackItem(type: .detectionQuality, message: "Could not detect key leg joints consistently in the video. Ensure good lighting & visibility.", frameIndex: nil, timestamp: nil))
        } else if Double(framesWithSufficientPoses) / Double(totalFrames) < 0.6 {
            feedback.append(FeedbackItem(type: .detectionQuality, message: "Detection Quality: Low confidence in some parts. Ensure good lighting & full body visibility.", frameIndex: nil, timestamp: nil))
        }
        return feedback
    }

    // MARK: - Real-Time Analysis Functionality

    func getLastDetectedPose() -> [CGPoint?]? {
        return self.lastPose
    }

    func cleanupLiveAnalysisState() {
        currentSquatPhase = .idle
        repCount = 0
        currentRepPoses.removeAll()
        currentRepTimestamps.removeAll()
        lastPose = nil
        peakHipHeight = nil
        valleyHipHeight = nil
        startOfDescentTimestamp = nil
        print("Live analysis state cleaned up.")
    }
    
    func getCurrentRepCount() -> Int {
        return repCount
    }

    // Main entry point for processing a live camera frame
    // This will return immediate feedback and potentially trigger detailed feedback for a completed rep
    @MainActor // Ensure UI updates from ViewModel are safe
    func processLiveFrame(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async -> (liveFeedback: LiveFeedback?, completedRepFeedback: [FeedbackItem]?) {
        guard let posePoints = try? await performPoseEstimation(on: pixelBuffer, isLive: true) else {
            self.lastPose = Array(repeating: nil, count: neededJoints.count)
            return (LiveFeedback(message: "No pose detected.", type: .detectionQuality, posePoints: self.lastPose), nil)
        }

        self.lastPose = posePoints // Update for drawing
        var immediateFeedbackMessage: String?
        var immediateFeedbackType: FeedbackItem.FeedbackType = .positive
        var completedRepFeedbackItems: [FeedbackItem]? = nil

        // --- State Machine for Squat Phase Detection ---
        let avgHipY = averagePoint(p1: posePoints[lHipIdx], p2: posePoints[rHipIdx])?.y
        let avgShoulderY = averagePoint(p1: posePoints[lShoulderIdx], p2: posePoints[rShoulderIdx])?.y
        
        // Store current pose and timestamp for the rep
        currentRepPoses.append(posePoints)
        currentRepTimestamps.append(timestamp)


        switch currentSquatPhase {
        case .idle:
            immediateFeedbackMessage = "Get ready to squat. Reps: \(repCount)"
            if let hipY = avgHipY {
                if peakHipHeight == nil { peakHipHeight = hipY } // Establish initial standing height
                
                // Start descent if hip drops significantly from peak
                if hipY < (peakHipHeight ?? 1.0) - hipMovementThreshold {
                    currentSquatPhase = .descending
                    startOfDescentTimestamp = timestamp
                    valleyHipHeight = hipY // Initial valley
                    currentRepPoses = [posePoints] // Start of new rep
                    currentRepTimestamps = [timestamp]
                    print("Phase: Idle -> Descending")
                    immediateFeedbackMessage = "Starting descent..."
                } else {
                    // Update peak if user stands taller
                     peakHipHeight = max(peakHipHeight ?? 0.0, hipY)
                }
            }
        case .descending:
            immediateFeedbackMessage = "Going down..."
            if let hipY = avgHipY {
                valleyHipHeight = min(valleyHipHeight ?? 1.0, hipY)
                // Check if starting to ascend (hip moves up from valley)
                if hipY > (valleyHipHeight ?? 0.0) + hipMovementThreshold * 0.5 { // More sensitive for ascent start
                    currentSquatPhase = .bottom // Briefly mark bottom then transition
                    print("Phase: Descending -> Bottom (transitory)")
                    // Analyze form at the "bottom" (which was the last frame of descent)
                    let bottomPoseForFeedback = currentRepPoses.last ?? posePoints // Use most recent
                    let instantBottomFeedback = analyzeSinglePoseLive(pose: bottomPoseForFeedback, phase: .bottom, timestamp: timestamp)
                    if !instantBottomFeedback.isEmpty {
                        immediateFeedbackMessage = instantBottomFeedback.first?.message
                        immediateFeedbackType = instantBottomFeedback.first?.type ?? .positive
                    } else {
                        immediateFeedbackMessage = "At the bottom"
                    }
                    currentSquatPhase = .ascending // Immediately transition to ascending
                    print("Phase: Bottom -> Ascending")
                }
                // Basic live feedback during descent (can be more sophisticated)
                let depthFeedback = checkSquatDepth(poses: [], bottomFrameIndex: 0, timestamps: [], isLive: true, livePose: posePoints).first
                if let depthMsg = depthFeedback, depthMsg.type == .depth {
                    immediateFeedbackMessage = depthMsg.message
                    immediateFeedbackType = .depth
                }
            } else { // Lost hip tracking
                currentSquatPhase = .idle
                peakHipHeight = nil
                print("Phase: Descending -> Idle (lost tracking)")
            }

        case .bottom: // This state is now very transitory
             // Logic moved to end of .descending and start of .ascending
             // This state might be used if you want to enforce a pause at the bottom
            immediateFeedbackMessage = "Hold..."
            // Transition to ascending would be triggered by hip starting to rise
            currentSquatPhase = .ascending // Should have transitioned already

        case .ascending:
            immediateFeedbackMessage = "Coming up..."
            if let hipY = avgHipY, let initialPeak = peakHipHeight {
                // Check if returned to near starting height
                if hipY > initialPeak - hipMovementThreshold * 0.8 { // Give some leeway
                    // Check rep duration
                    if let startTime = startOfDescentTimestamp, CMTimeGetSeconds(CMTimeSubtract(timestamp, startTime)) > minRepDuration {
                        repCount += 1
                        currentSquatPhase = .completedRep
                        print("Phase: Ascending -> CompletedRep (Rep \(repCount))")
                        
                        // Analyze the completed rep
                        // TODO: Ensure frameData is correctly constructed for analyzeFullSquatSequence if reusing
                        // Or create a simplified live rep analysis function
                        let repFrameData = FrameData(pixelBuffers: [], timestamps: currentRepTimestamps, videoSize: .zero, frameDuration: estimateFrameDuration())
                        completedRepFeedbackItems = analyzeLiveRep(poses: currentRepPoses, frameData: repFrameData)
                        
                        immediateFeedbackMessage = "Rep \(repCount) Complete!"
                        immediateFeedbackType = .repComplete
                        
                        // Prepare for next rep
                        currentRepPoses.removeAll()
                        currentRepTimestamps.removeAll()
                        peakHipHeight = hipY // Reset peak for next rep
                        valleyHipHeight = nil
                        
                         // Transition to idle after a short delay or immediately
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if self.currentSquatPhase == .completedRep { // Ensure still in this phase
                                 self.currentSquatPhase = .idle
                                 print("Phase: CompletedRep -> Idle (auto-transition)")
                            }
                        }
                    } else { // Rep too short
                        print("Rep too short, resetting.")
                        currentSquatPhase = .idle
                        peakHipHeight = hipY
                        valleyHipHeight = nil
                        currentRepPoses.removeAll()
                        currentRepTimestamps.removeAll()
                        immediateFeedbackMessage = "Rep too fast, try again."
                        immediateFeedbackType = .liveInstruction
                    }
                } else {
                    // Provide feedback during ascent (e.g. knee valgus, torso angle)
                     let ascentFeedback = analyzeSinglePoseLive(pose: posePoints, phase: .ascending, timestamp: timestamp)
                     if !ascentFeedback.isEmpty {
                         immediateFeedbackMessage = ascentFeedback.first?.message
                         immediateFeedbackType = ascentFeedback.first?.type ?? .positive
                     }
                }
            } else { // Lost hip tracking
                currentSquatPhase = .idle
                peakHipHeight = nil
                print("Phase: Ascending -> Idle (lost tracking)")
            }
        case .completedRep:
            // Already handled, waiting for auto-transition to idle
            // Or user can explicitly start next rep by moving
            immediateFeedbackMessage = "Nice rep! (\(repCount)) Get ready..."
            // If user starts moving down again, transition to descending
            if let hipY = avgHipY, let currentPeak = peakHipHeight, hipY < currentPeak - hipMovementThreshold {
                currentSquatPhase = .descending
                startOfDescentTimestamp = timestamp
                valleyHipHeight = hipY
                currentRepPoses = [posePoints]
                currentRepTimestamps = [timestamp]
                print("Phase: CompletedRep -> Descending (early start)")
            }
        }
        
        let liveFb = LiveFeedback(message: immediateFeedbackMessage ?? "Processing...", type: immediateFeedbackType, posePoints: posePoints)
        return (liveFb, completedRepFeedbackItems)
    }
    
    private func estimateFrameDuration() -> CMTime? {
        // If processing live frames, we might assume a certain FPS like 30.
        // Or, it could be passed in if known from camera config.
        // This is mainly for `checkAscentRate` if used for live rep analysis.
        return CMTime(value: 1, timescale: 30) // Assume 30 FPS for now
    }

    // Analyze a single pose for immediate live feedback (simplified checks)
    private func analyzeSinglePoseLive(pose: [CGPoint?], phase: SquatPhase, timestamp: CMTime) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []
        // Apply a subset of rules that make sense for instant feedback on a single frame
        
        // Example: Knee Valgus Check (can be checked continuously)
        let valgusFeedback = checkKneeValgus(poses: [], bottomFrameIndex: 0, timestamps: [timestamp], isLive: true, livePose: pose)
        feedback.append(contentsOf: valgusFeedback)

        // Example: Torso Angle (especially at bottom or during ascent)
        if phase == .bottom || phase == .ascending {
            let torsoFeedback = checkTorsoAngle(poses: [], bottomFrameIndex: 0, timestamps: [timestamp], isLive: true, livePose: pose)
            feedback.append(contentsOf: torsoFeedback)
        }
        
        // Example: Heel Lift
        let heelLiftFb = checkHeelLift(poses: [], timestamps: [timestamp], isLive: true, livePose: pose)
        feedback.append(contentsOf: heelLiftFb)

        // Limit to one piece of feedback at a time to avoid overwhelming the user
        return feedback.isEmpty ? [] : [feedback.first!]
    }

    // Analyze a completed live repetition (uses a sequence of poses for that rep)
    private func analyzeLiveRep(poses: [[CGPoint?]], frameData: FrameData) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []
        guard !poses.isEmpty else { return feedback }

        // Find bottom of this specific rep's poses
        var minAvgHipY: CGFloat = 1.0
        var bottomFrameIndex: Int? = nil
        for (index, framePoses) in poses.enumerated() {
            let leftHipY = framePoses[lHipIdx]?.y
            let rightHipY = framePoses[rHipIdx]?.y
            var currentAvgHipY: CGFloat?
            if let lY = leftHipY, let rY = rightHipY { currentAvgHipY = (lY + rY) / 2.0 }
            else { currentAvgHipY = leftHipY ?? rightHipY }

            if let avgY = currentAvgHipY {
                if avgY < minAvgHipY {
                    minAvgHipY = avgY
                    bottomFrameIndex = index
                }
            }
        }
        
        guard let bottomIdx = bottomFrameIndex else {
            feedback.append(FeedbackItem(type: .detectionQuality, message: "Could not determine bottom of live rep.", frameIndex: nil, timestamp: nil)) // Pass nil as bottomIdx is not in scope
            return feedback
        }
        
        var issuesFoundInRep = false

        // Now call the detailed check functions, passing the poses for THIS REP
        let depthFeedback = checkSquatDepth(poses: poses, bottomFrameIndex: bottomIdx, timestamps: frameData.timestamps, isLive: false, livePose: nil) // isLive=false to use array
        if depthFeedback.contains(where: { $0.type == .depth }) { issuesFoundInRep = true }
        feedback.append(contentsOf: depthFeedback)
        
        let kneeValgusFeedback = checkKneeValgus(poses: poses, bottomFrameIndex: bottomIdx, timestamps: frameData.timestamps, isLive: false, livePose: nil)
        if !kneeValgusFeedback.isEmpty { issuesFoundInRep = true }
        feedback.append(contentsOf: kneeValgusFeedback)
        
        let torsoFeedback = checkTorsoAngle(poses: poses, bottomFrameIndex: bottomIdx, timestamps: frameData.timestamps, isLive: false, livePose: nil)
        if torsoFeedback.contains(where: { $0.type == .torsoAngle }) { issuesFoundInRep = true }
        feedback.append(contentsOf: torsoFeedback)
        
        let heelLiftFeedback = checkHeelLift(poses: poses, timestamps: frameData.timestamps, isLive: false, livePose: nil)
        if !heelLiftFeedback.isEmpty { issuesFoundInRep = true }
        feedback.append(contentsOf: heelLiftFeedback)

        if let frameDuration = frameData.frameDuration {
            let ascentFeedback = checkAscentRate(poses: poses, bottomFrameIndex: bottomIdx, frameDuration: frameDuration, timestamps: frameData.timestamps)
            if !ascentFeedback.isEmpty { issuesFoundInRep = true }
            feedback.append(contentsOf: ascentFeedback)
        }
        
        // Add positive feedback if no specific issues were flagged for this rep from the checks above
        // Also include the positive depth feedback if it was good.
        let positiveDepth = depthFeedback.first(where: { $0.type == .positive })

        if !issuesFoundInRep {
            if let pd = positiveDepth {
                 feedback.append(FeedbackItem(type: .positive, message: "Good depth on that rep!", frameIndex: bottomIdx, timestamp: frameData.timestamps[safe: bottomIdx]))
            } else {
                // If no specific issues AND depth wasn't specifically praised (e.g., it was just okay, not bad)
                // add a general positive note.
                 feedback.append(FeedbackItem(type: .positive, message: "Good overall form on that rep!", frameIndex: bottomIdx, timestamp: frameData.timestamps[safe: bottomIdx]))
            }
        } else if let pd = positiveDepth {
            // If there were other issues, but depth was good, still add the positive depth note.
            feedback.append(pd)
        }
        
        // Add a specific "Rep Complete" item that can be filtered out if needed from pure form feedback
        feedback.append(FeedbackItem(type: .repComplete, message: "Rep analyzed.", frameIndex: bottomIdx, timestamp: frameData.timestamps[safe: bottomIdx]))
        
//        let negativeFeedbackCount = feedback.filter { $0.type != .positive && $0.type != .detectionQuality }.count
//        if negativeFeedbackCount == 0 {
//            feedback.append(FeedbackItem(type: .positive, message: "Good rep!", frameIndex: bottomIdx, timestamp: frameData.timestamps[safe: bottomIdx]))
//        }

        return feedback
    }


    // --- Modified Form Check Functions to support both live (single pose) and sequence ---
    // (as in your provided PoseAnalyzer.txt source: 43-86, with modifications)
    // Example for checkSquatDepth:
    private func checkSquatDepth(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime], isLive: Bool, livePose: [CGPoint?]?) -> [FeedbackItem] {
        let poseToAnalyze: [CGPoint?]?
        let timestampToUse: CMTime?
        let frameIdxToUse: Int?

        if isLive {
            poseToAnalyze = livePose
            timestampToUse = timestamps.first // Assuming timestamps for live is just the current frame's
            frameIdxToUse = nil // Frame index not relevant for single live frame in same way
        } else {
            guard let p = poses[safe: bottomFrameIndex] else { return [] }
            poseToAnalyze = p
            timestampToUse = timestamps[safe: bottomFrameIndex]
            frameIdxToUse = bottomFrameIndex
        }
        guard let currentPose = poseToAnalyze else { return [] }

        let leftKneeAngle = calculateAngle(p1Idx: lAnkleIdx, p2Idx: lKneeIdx, p3Idx: lHipIdx, pose: currentPose)
        let rightKneeAngle = calculateAngle(p1Idx: rAnkleIdx, p2Idx: rKneeIdx, p3Idx: rHipIdx, pose: currentPose)
        var avgKneeAngle: CGFloat?
        if let lAngle = leftKneeAngle, let rAngle = rightKneeAngle { avgKneeAngle = (lAngle + rAngle) / 2.0 }
        else { avgKneeAngle = leftKneeAngle ?? rightKneeAngle }

        guard let kneeAngle = avgKneeAngle else {
            if isLive { print("Live Depth Check: Could not calculate knee angle.") }
            else { print("Video Depth Check: Could not calculate knee angle at bottom.") }
            return []
        }

        let depthThresholdAngle: CGFloat = 100.0
        // if isLive { print("Live Depth Check: Knee angle \(kneeAngle)°") }

        if kneeAngle > depthThresholdAngle {
            return [FeedbackItem(type: .depth,
                                 message: "Squat Depth: Go deeper. Aim hip crease below knee (angle < ~\(Int(depthThresholdAngle))°). Now: \(Int(kneeAngle))°.",
                                 frameIndex: frameIdxToUse,
                                 timestamp: timestampToUse)]
        } else if !isLive { // Only give positive feedback for depth on full sequence analysis or completed rep
             return [FeedbackItem(type: .positive, message: "Squat Depth: Great depth!", frameIndex: frameIdxToUse, timestamp: timestampToUse)]
        }
        return []
    }
    
    private func checkKneeValgus(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime], isLive: Bool, livePose: [CGPoint?]?) -> [FeedbackItem] {
        let kneeCaveThresholdRatio: CGFloat = 0.90 // If knee horizontal distance < 90% of ankle distance
        
        // Helper closure to determine if the view is likely from the side
        // This checks the horizontal separation of the shoulders.
        // If shoulders are close horizontally, it implies a profile or near-profile view.
        let isLikelySideViewHeuristic = { (pose: [CGPoint?]?) -> Bool in
            guard let p = pose,
                  let leftShoulderPoint = p[self.lShoulderIdx], // Use self if accessing instance members
                  let rightShoulderPoint = p[self.rShoulderIdx] else {
                // If shoulders aren't detected, we can't use this heuristic.
                // Default to false (assume not a side view) to allow valgus check,
                // or true to be cautious and skip valgus if shoulders are key to the check.
                // Let's default to false for now, meaning the valgus check will proceed if shoulders are missing.
                return false
            }
            let shoulderSeparationX = abs(leftShoulderPoint.x - rightShoulderPoint.x)

            // Threshold: If horizontal shoulder separation is less than (e.g.) 15% of the view width.
            // This value (0.15) may need tuning based on your typical camera setup and how "sideways" the view is.
            // A smaller value means it needs to be more directly a side view to skip the check.
            return shoulderSeparationX < 0.15
        }

        if isLive {
            guard let currentPose = livePose,
                  let lKnee = currentPose[lKneeIdx], let rKnee = currentPose[rKneeIdx],
                  let lAnkle = currentPose[lAnkleIdx], let rAnkle = currentPose[rAnkleIdx] else {
                return []
            }
            if isLikelySideViewHeuristic(currentPose) {
                print("Knee Valgus (Live): Likely side view detected. Skipping valgus check.")
                return [] // Skip valgus check if likely a side view
            }

            // Proceed with existing live valgus logic only if not a side view
            let kneeDistance = abs(lKnee.x - rKnee.x)
            let ankleDistance = abs(lAnkle.x - rAnkle.x)
            if ankleDistance > 0.01 && (kneeDistance / ankleDistance) < kneeCaveThresholdRatio {
                return [FeedbackItem(type: .kneeValgus,
                                     message: "Knees In: Push knees out over feet.",
                                     frameIndex: nil,
                                     timestamp: timestamps.first)]
            }
        } else { // Video sequence analysis
            // For video, check the side view heuristic on the bottom frame of the squat.
            // If this critical frame is a side view, we'll skip the valgus check for the sequence.
            // This is an approximation; if the camera angle changes significantly during the video,
            // a per-frame side view check within the loop might be more robust but also more complex.
            if let bottomPoseForCheck = poses[safe: bottomFrameIndex], isLikelySideViewHeuristic(bottomPoseForCheck) {
                print("Knee Valgus (Video): Likely side view detected at squat bottom. Skipping valgus check for sequence.")
                return [] // Skip valgus check
            }
            
            var valgusFrames: [Int] = []
            for (index, framePoses) in poses.enumerated() {
                guard let lKnee = framePoses[lKneeIdx], let rKnee = framePoses[rKneeIdx],
                      let lAnkle = framePoses[lAnkleIdx], let rAnkle = framePoses[rAnkleIdx] else {
                    continue
                }
                let kneeDistance = abs(lKnee.x - rKnee.x)
                let ankleDistance = abs(lAnkle.x - rAnkle.x)
                if ankleDistance > 0.01 && (kneeDistance / ankleDistance) < kneeCaveThresholdRatio {
                    valgusFrames.append(index)
                }
            }
            if !valgusFrames.isEmpty {
                let ascentStartIndex = bottomFrameIndex + 1
                let firstValgusOnAscent = valgusFrames.first(where: { $0 >= ascentStartIndex })
                let worstValgusFrame = firstValgusOnAscent ?? valgusFrames.last
                if let frameIdx = worstValgusFrame {
                    return [FeedbackItem(type: .kneeValgus,
                                         message: "Knee Position: Avoid letting knees cave inward ('valgus'), especially when standing up. Push knees out over your feet.",
                                         frameIndex: frameIdx,
                                         timestamp: timestamps[safe: frameIdx])]
                }
            }
        }
        return []
    }
    
    // Similar modifications for checkTorsoAngle, checkHeelLift
    // checkTorsoAngle, checkHeelLift, checkAscentRate, calculateAngle, angleBetweenVectors, angleWithVertical,
    // safeGetPoint, averagePoint should be adapted or used carefully for live single pose context.
    // For brevity, I'll assume you can adapt these using the 'isLive' flag and 'livePose' parameter
    // as shown for checkSquatDepth and checkKneeValgus.
    // The existing logic for sequences (isLive = false) should remain.
    // For `checkAscentRate`, it inherently needs a sequence, so it would only apply to `analyzeLiveRep` or `analyzeFullSquatSequence`.

    // (Make sure all other helper functions from your original PoseAnalyzer.txt source are included,
    //  like calculateAngle, angleBetweenVectors, averagePoint, etc.)
    // --- Angle Calculation Helpers --- (as in your PoseAnalyzer.txt source: 87-99)
    private func calculateAngle(p1: CGPoint?, p2: CGPoint?, p3: CGPoint?) -> CGFloat? {
        guard let p1 = p1, let p2 = p2, let p3 = p3 else { return nil }
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        let angle1 = atan2(v1.y, v1.x)
        let angle2 = atan2(v2.y, v2.x)
        var angle = angle1 - angle2
        while angle < 0 { angle += .pi * 2 }
        while angle >= .pi * 2 { angle -= .pi * 2 }
        let degrees = angle * 180.0 / .pi
        return min(degrees, 360.0 - degrees)
    }

    private func calculateAngle(p1Idx: Int, p2Idx: Int, p3Idx: Int, pose: [CGPoint?]) -> CGFloat? {
         return calculateAngle(p1: pose[safe: p1Idx] ?? nil,
                               p2: pose[safe: p2Idx] ?? nil,
                               p3: pose[safe: p3Idx] ?? nil)
    }
    
    private func angleWithVertical(vector: CGPoint) -> CGFloat {
        guard vector.x != 0 || vector.y != 0 else { return 0 }
        let angleRadians = atan2(vector.x, vector.y) // atan2(x,y) for angle from positive Y (vertical up)
        var angleDegrees = angleRadians * 180.0 / .pi
        // We want the acute angle with the vertical line, irrespective of direction (0-90 for lean)
        // If vector.y is positive, it's mostly upwards. If negative, mostly downwards.
        // atan2(x,y) -> angle from +Y. If y is negative, vector points down.
        // Example: (0,1) -> 0 deg. (1,0) -> 90 deg. (0,-1) -> 180 deg. (-1,0) -> 270 deg.
        // For torso lean, we typically care about deviation from the vertical axis (y-axis).
        // A vector (dx, dy) = (shoulder.x - hip.x, shoulder.y - hip.y)
        // If dy is positive, shoulder is above hip (more upright). If dy is negative, shoulder is below hip (more inverted).
        // We want the angle with the Y axis.
        let rawAngleWithPositiveY = atan2(vector.x, abs(vector.y)) * 180.0 / .pi // Angle from "some" vertical, ensuring Y is positive for calculation
        return abs(rawAngleWithPositiveY) // Interested in magnitude of lean from vertical
    }


    private func averagePoint(p1: CGPoint?, p2: CGPoint?) -> CGPoint? {
        if let p1 = p1, let p2 = p2 {
            return CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
        } else {
            return p1 ?? p2
        }
    }
    
    // checkTorsoAngle - MODIFIED
    private func checkTorsoAngle(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime], isLive: Bool, livePose: [CGPoint?]?) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []
        let poseToAnalyze: [CGPoint?]?
        let timestampToUse: CMTime?
        let frameIdxToUse: Int?

        if isLive {
            poseToAnalyze = livePose
            timestampToUse = timestamps.first
            frameIdxToUse = nil
        } else {
            guard let p = poses[safe: bottomFrameIndex] else { return [] }
            poseToAnalyze = p
            timestampToUse = timestamps[safe: bottomFrameIndex]
            frameIdxToUse = bottomFrameIndex
        }
        guard let currentBottomPose = poseToAnalyze,
              let avgShoulder = averagePoint(p1: currentBottomPose[lShoulderIdx], p2: currentBottomPose[rShoulderIdx]),
              let avgHip = averagePoint(p1: currentBottomPose[lHipIdx], p2: currentBottomPose[rHipIdx]) else {
            // print("Torso Check: Missing key joints.")
            return []
        }

        let torsoVector = CGPoint(x: avgShoulder.x - avgHip.x, y: avgShoulder.y - avgHip.y) // hip to shoulder
        let torsoAngleFromVertical = angleWithVertical(vector: torsoVector) // Angle from vertical
        
        let leanThreshold: CGFloat = 55.0 // Max angle from vertical.
        // print("Torso angle from vertical: \(torsoAngleFromVertical)")

        if torsoAngleFromVertical > leanThreshold {
             feedback.append(FeedbackItem(type: .torsoAngle,
                                          message: "Torso Lean: Excessive forward lean (\(Int(torsoAngleFromVertical))°). Keep chest up.",
                                          frameIndex: frameIdxToUse,
                                          timestamp: timestampToUse))
        } else if !isLive && feedback.isEmpty { // Only positive for full sequence if no other torso issue
            // Optional: Positive feedback if not live and angle is good
        }

        // For video sequence: Check for change in torso angle (rounding/arching)
        if !isLive {
            // ... (Your existing logic for checking change in torso angle over the sequence) ...
            // This part is complex to adapt meaningfully for single live frames without more state.
            // So, it remains primarily for video analysis or completed live rep analysis.
        }
        return feedback
    }

    // checkHeelLift - MODIFIED
    private func checkHeelLift(poses: [[CGPoint?]], timestamps: [CMTime], isLive: Bool, livePose: [CGPoint?]?) -> [FeedbackItem] {
        let liftThreshold: CGFloat = 0.02 // Normalized Y lift threshold
        
        if isLive {
            guard let currentPose = livePose,
                  let lAnkle = currentPose[lAnkleIdx], let rAnkle = currentPose[rAnkleIdx] else { return [] }
            // For live, it's harder to define "initial" Y without more state.
            // A simpler live check might be if ankles are significantly higher than knees in Y (if feet are off screen bottom)
            // Or, if you have a reference "floor" line.
            // For now, this live check will be less effective without a baseline.
            // One approach for live: if ankle Y is much higher than its historical minimum during the squat.
            // This needs more sophisticated state tracking for live.
            return [] // Placeholder for more robust live heel lift
        } else { // Video sequence analysis
            var initialAnkleY: CGFloat? = nil
            var maxHeelLiftFrame: Int? = nil
            var maxLiftAmount: CGFloat = 0.0

            for (index, framePose) in poses.enumerated() {
                guard let lAnkle = framePose[lAnkleIdx], let rAnkle = framePose[rAnkleIdx] else { continue }
                let currentAvgAnkleY = (lAnkle.y + rAnkle.y) / 2.0
                if initialAnkleY == nil { initialAnkleY = currentAvgAnkleY }
                if let initialY = initialAnkleY {
                    let liftAmount = currentAvgAnkleY - initialY // Y increases upwards on screen
                    if liftAmount > liftThreshold && liftAmount > maxLiftAmount { // Vision Y is 0 at bottom, 1 at top. So if current Y is GREATER than initial Y, it has lifted.
                        maxLiftAmount = liftAmount
                        maxHeelLiftFrame = index
                    }
                }
            }
            if let liftFrame = maxHeelLiftFrame {
                return [FeedbackItem(type: .heelLift,
                                     message: "Heels: Heels lifted. Keep feet flat.",
                                     frameIndex: liftFrame,
                                     timestamp: timestamps[safe: liftFrame])]
            }
        }
        return []
    }
    
    // checkAscentRate - Primarily for sequence analysis (video or completed live rep)
    // (as in your provided PoseAnalyzer.txt source: 78-86)
    private func checkAscentRate(poses: [[CGPoint?]], bottomFrameIndex: Int, frameDuration: CMTime?, timestamps: [CMTime]) -> [FeedbackItem] {
        guard let frameDurSecs = frameDuration?.seconds, frameDurSecs > 0, bottomFrameIndex + 2 < poses.count else {
            return []
        }
        let ascentStartIdx = bottomFrameIndex + 1
        let ascentEndIdx = min(bottomFrameIndex + 3, poses.count - 1)

        guard let startPose = poses[safe: ascentStartIdx],
              let endPose = poses[safe: ascentEndIdx],
              let startHipY = averagePoint(p1: startPose[lHipIdx], p2: startPose[rHipIdx])?.y,
              let endHipY = averagePoint(p1: endPose[lHipIdx], p2: endPose[rHipIdx])?.y,
              let startShoulderY = averagePoint(p1: startPose[lShoulderIdx], p2: startPose[rShoulderIdx])?.y,
              let endShoulderY = averagePoint(p1: endPose[lShoulderIdx], p2: endPose[rShoulderIdx])?.y
               else { return [] }

        let timeElapsed = Double(ascentEndIdx - ascentStartIdx) * frameDurSecs
        guard timeElapsed > 0 else { return [] }

        let hipVelocity = (endHipY - startHipY) / CGFloat(timeElapsed)
        let shoulderVelocity = (endShoulderY - startShoulderY) / CGFloat(timeElapsed)
        let velocityRatioThreshold: CGFloat = 1.5

        if hipVelocity > shoulderVelocity * velocityRatioThreshold && shoulderVelocity > 0 {
             return [FeedbackItem(type: .ascentRate,
                                  message: "Ascent: Hips rising faster than shoulders. Drive up with chest & hips together.",
                                  frameIndex: ascentStartIdx,
                                  timestamp: timestamps[safe: ascentStartIdx])]
        }
        return []
    }


} // End of PoseAnalyzer Class

// Helper struct for FrameData (as in your provided PoseAnalyzer.txt source: 21)
struct FrameData {
    let pixelBuffers: [CVPixelBuffer]
    let timestamps: [CMTime]
    let videoSize: CGSize
    let frameDuration: CMTime?
}

// Helper extension for safe array access (as in your provided PoseAnalyzer.txt source: 100-101)
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Helper for CMTime to get seconds safely (as in your provided PoseAnalyzer.txt source: 102-103)
extension CMTime {
    var seconds: Double? {
        let seconds = CMTimeGetSeconds(self)
        return seconds.isNaN ? nil : seconds
    }
}
