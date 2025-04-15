import AVFoundation
import Vision
import UIKit // Needed for UIImage, CGPoint calculations
import CoreImage // For CIContext

// New struct to hold feedback and associated frame info
// Added FeedbackType for potential filtering or icon display later
struct FeedbackItem: Identifiable, Hashable {
    enum FeedbackType: String {
        case depth = "Depth"
        case kneeValgus = "Knee Position"
        case torsoAngle = "Torso/Back Posture"
        case heelLift = "Heel Position"
        case ascentRate = "Ascent Rate"
        case detectionQuality = "Detection Quality"
        case positive = "Good Form"
    }

    let id = UUID() // Unique ID for list iteration
    let type: FeedbackType
    let message: String
    let frameIndex: Int? // Index of the frame where the issue was most prominent
    let timestamp: CMTime? // Timestamp of that frame
    
    // Properties for Actionable Feedback (populated by ViewModel)
    var detailedExplanation: String? = nil
    var potentialCauses: String? = nil
    var correctiveSuggestions: String? = nil // Can contain formatted text or list

    // Make Hashable based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: FeedbackItem, rhs: FeedbackItem) -> Bool {
        lhs.id == rhs.id
    }
}

class PoseAnalyzer {

    // Cache for frame images to avoid redundant loading
    private var imageGenerator: AVAssetImageGenerator?
    private var ciContext = CIContext()


    // --- Joint Indices Mapping ---
    // Define these constants for clarity and easier modification
    private let rootIdx = 0
    private let lHipIdx = 1
    private let rHipIdx = 2
    private let lKneeIdx = 3
    private let rKneeIdx = 4
    private let lAnkleIdx = 5
    private let rAnkleIdx = 6
    private let lShoulderIdx = 7
    private let rShoulderIdx = 8
    // Array of needed joints for Vision request
    private let neededJoints: [VNHumanBodyPoseObservation.JointName] = [
             .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftShoulder, .rightShoulder
         ]


    // Main analysis function
    func analyzeSquatVideo(url: URL) async throws -> [FeedbackItem] {

        print("Starting analysis for video: \(url.lastPathComponent)")

        // Prepare the image generator
        let asset = AVURLAsset(url: url)
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.appliesPreferredTrackTransform = true
        imageGenerator?.requestedTimeToleranceBefore = .zero
        imageGenerator?.requestedTimeToleranceAfter = .zero

        // 1. Read video frames
        let frameData = try await readVideoFrames(url: url)

        guard !frameData.pixelBuffers.isEmpty else {
            imageGenerator = nil // Clean up
            print("Analysis stopped: No frames read from video.")
            return [FeedbackItem(type: .detectionQuality, message: "Could not read any frames from the video.", frameIndex: nil, timestamp: nil)]
        }

        print("Read \(frameData.pixelBuffers.count) frames. Starting pose estimation...")

        // 2. Perform Pose Estimation
        var allFramePoses: [[CGPoint?]] = []
        for (index, frame) in frameData.pixelBuffers.enumerated() {
            if index % 10 == 0 || index == frameData.pixelBuffers.count - 1 {
                print("  Processing frame \(index + 1)/\(frameData.pixelBuffers.count)...")
            }
            do {
                let posePoints = try await performPoseEstimation(on: frame)
                allFramePoses.append(posePoints)
            } catch {
                print("  Error during pose estimation for frame \(index): \(error.localizedDescription). Skipping frame.")
                 allFramePoses.append(Array(repeating: nil, count: neededJoints.count))
            }
        }

        // --- Pose Detection Quality Check ---
        print("Finished processing frames. Checking detection quality...")
        let totalFrames = allFramePoses.count
        // Count frames where at least hip, knee, and ankle are detected on one side
        let framesWithSufficientPoses = allFramePoses.filter { frame in
            (frame[lHipIdx] != nil && frame[lKneeIdx] != nil && frame[lAnkleIdx] != nil) ||
            (frame[rHipIdx] != nil && frame[rKneeIdx] != nil && frame[rAnkleIdx] != nil)
        }.count

        print("  - Total frames processed: \(totalFrames)")
        print("  - Frames with sufficient leg poses detected: \(framesWithSufficientPoses) / \(totalFrames)")

        if totalFrames > 0 && framesWithSufficientPoses == 0 {
            imageGenerator = nil // Clean up
             print("Error Check Triggered: Found 0 frames with sufficient leg poses detected.")
            return [FeedbackItem(type: .detectionQuality, message: "Could not detect key leg joints consistently in the video. Ensure good lighting & visibility.", frameIndex: nil, timestamp: nil)]
        }

        var initialFeedback: [FeedbackItem] = []
        if Double(framesWithSufficientPoses) / Double(totalFrames) < 0.6 { // Trigger if less than 60% frames have sufficient poses
             initialFeedback.append(FeedbackItem(type: .detectionQuality, message: "Detection Quality: Low confidence in some parts. Ensure good lighting & full body visibility.", frameIndex: nil, timestamp: nil))
        }

        print("Pose data sufficient (\(framesWithSufficientPoses) frames). Proceeding to analyzeSquatForm.")

        // 3. Analyze the sequence of poses
        let analysisFeedback = analyzeSquatForm(poses: allFramePoses, frameData: frameData)

        // Combine initial feedback (like low confidence) with analysis feedback
        return initialFeedback + analysisFeedback
    }

    // Function to fetch a specific frame as UIImage
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

    // Clean up the image generator
    func cleanupGenerator() {
        imageGenerator = nil
        print("Image generator cleaned up.")
    }


    // --- Helper: Reading Video Frames ---
    private struct FrameData {
        let pixelBuffers: [CVPixelBuffer]
        let timestamps: [CMTime]
        let videoSize: CGSize
        let frameDuration: CMTime? // Duration of a single frame
    }

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
                 CMSampleBufferInvalidate(sampleBuffer) // Release sample buffer
            } else if reader.status == .completed {
                 break
            } else if reader.status == .failed {
                print("Reader failed with error: \(reader.error?.localizedDescription ?? "Unknown error")")
                throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
            }
             // Yield to allow other tasks to run, prevent blocking main thread heavily
             try? await Task.sleep(nanoseconds: 1_000) // 1 microsecond yield
        }

        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
        }
        print("Successfully read \(pixelBuffers.count) frames.")
        return FrameData(pixelBuffers: pixelBuffers, timestamps: timestamps, videoSize: videoSize, frameDuration: frameDuration)
    }

    // --- Helper: Performing Pose Estimation ---
    private func performPoseEstimation(on pixelBuffer: CVPixelBuffer) async throws -> [CGPoint?] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up) // Assuming video is upright

        try handler.perform([request]) // Can throw

        guard let observation = request.results?.first else {
            // Vision found no pose at all
            return Array(repeating: nil, count: neededJoints.count)
        }

        // Get all detected points from the observation
        let allRecognizedPoints = try observation.recognizedPoints(.all)

        var framePoints: [CGPoint?] = []
        for jointName in neededJoints {
            // Check if the joint was recognized *and* has sufficient confidence
            if let point = allRecognizedPoints[jointName], point.confidence > 0.1 {
                // Vision coordinates are normalized (0,0 bottom-left). Convert to UIKit (0,0 top-left) if needed for drawing,
                // but for internal calculations (angles, relative positions), normalized coordinates are fine.
                // Let's keep them normalized for analysis.
                framePoints.append(point.location)
            } else {
                framePoints.append(nil) // Joint not detected or low confidence
            }
        }
        return framePoints
    }


    // --- Helper: Analyzing Squat Form ---
    private func analyzeSquatForm(poses: [[CGPoint?]], frameData: FrameData) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []
        let timestamps = frameData.timestamps
        let frameCount = poses.count

        guard frameCount > 5 else { // Need a minimum number of frames for analysis
             return [FeedbackItem(type: .detectionQuality, message: "Video too short or too few poses detected for meaningful analysis.", frameIndex: nil, timestamp: nil)]
        }

        // --- Find the approximate bottom of the squat ---
        // Use average hip Y position to find the lowest point
        var minAvgHipY: CGFloat = 1.0 // Normalized Y goes from 0 (bottom) to 1 (top)
        var bottomFrameIndex: Int? = nil

        for (index, framePoses) in poses.enumerated() {
            let leftHipY = framePoses[lHipIdx]?.y
            let rightHipY = framePoses[rHipIdx]?.y

            // Average the Y position if both hips are detected, otherwise use whichever is available
            var currentAvgHipY: CGFloat?
            if let lY = leftHipY, let rY = rightHipY {
                currentAvgHipY = (lY + rY) / 2.0
            } else {
                currentAvgHipY = leftHipY ?? rightHipY
            }

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

        // --- Rule 1: Squat Depth (using Knee Angle) ---
        let depthFeedback = checkSquatDepth(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps)
        feedback.append(contentsOf: depthFeedback)


        // --- Rule 2: Knee Valgus (Knees Caving In) ---
        let kneeValgusFeedback = checkKneeValgus(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps)
        feedback.append(contentsOf: kneeValgusFeedback)


        // --- Rule 3: Torso Angle / Back Posture ---
        // Check torso angle relative to vertical at the bottom AND consistency throughout
        let torsoFeedback = checkTorsoAngle(poses: poses, bottomFrameIndex: bottomIdx, timestamps: timestamps)
        feedback.append(contentsOf: torsoFeedback)

        // --- Rule 4: Heel Lift ---
        let heelLiftFeedback = checkHeelLift(poses: poses, timestamps: timestamps)
        feedback.append(contentsOf: heelLiftFeedback)


        // --- Rule 5: Ascent Rate (Hips vs Shoulders) ---
        // Check if hips rise significantly faster than shoulders out of the bottom
         let ascentFeedback = checkAscentRate(poses: poses, bottomFrameIndex: bottomIdx, frameDuration: frameData.frameDuration, timestamps: timestamps)
         feedback.append(contentsOf: ascentFeedback)


        // --- Final Positive Feedback ---
        // If no major negative feedback items were added, add a positive note.
        let negativeFeedbackCount = feedback.filter { $0.type != .positive && $0.type != .detectionQuality }.count
        if negativeFeedbackCount == 0 && !feedback.contains(where: { $0.type == .detectionQuality && $0.message.contains("Could not detect") }) { // Ensure detection wasn't critically bad
             feedback.append(FeedbackItem(type: .positive, message: "Good overall squat form detected!", frameIndex: bottomIdx, timestamp: timestamps.indices.contains(bottomIdx) ? timestamps[bottomIdx] : nil))
        }


        return feedback
    }

    // --- Specific Form Check Functions ---

    private func checkSquatDepth(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime]) -> [FeedbackItem] {
        guard let bottomPose = poses[safe: bottomFrameIndex] else { return [] }

        // Calculate knee angle at the bottom. Use average of left/right if available.
        let leftKneeAngle = calculateAngle(p1Idx: lAnkleIdx, p2Idx: lKneeIdx, p3Idx: lHipIdx, pose: bottomPose)
        let rightKneeAngle = calculateAngle(p1Idx: rAnkleIdx, p2Idx: rKneeIdx, p3Idx: rHipIdx, pose: bottomPose)

        var avgKneeAngle: CGFloat?
        if let lAngle = leftKneeAngle, let rAngle = rightKneeAngle {
            avgKneeAngle = (lAngle + rAngle) / 2.0
        } else {
            avgKneeAngle = leftKneeAngle ?? rightKneeAngle
        }

        guard let kneeAngle = avgKneeAngle else {
            print("Depth Check: Could not calculate knee angle at bottom.")
            return []
        }

        let depthThresholdAngle: CGFloat = 100.0 // Angle degrees. Aiming for less than 90 is deep, 100 is slightly above parallel often. Needs tuning.
                                                 // Remember angle calculation: 180 is straight leg, 90 is right angle. Smaller angle = deeper squat.

        print("Depth Check: Knee angle at bottom frame \(bottomFrameIndex) is \(kneeAngle) degrees.")

        if kneeAngle > depthThresholdAngle {
            return [FeedbackItem(type: .depth,
                                 message: "Squat Depth: Try to go deeper. Aim for your hip crease to be below your knee top (knee angle < ~\(Int(depthThresholdAngle))°). Current angle: \(Int(kneeAngle))°.",
                                 frameIndex: bottomFrameIndex,
                                 timestamp: timestamps[safe: bottomFrameIndex])]
        } else {
             // Optionally add positive feedback for depth if desired, or handle in the final positive feedback check.
             return [FeedbackItem(type: .positive, message: "Squat Depth: Great depth!", frameIndex: bottomFrameIndex, timestamp: timestamps[safe: bottomFrameIndex])]
             return [] // No issue found
        }
    }


    private func checkKneeValgus(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime]) -> [FeedbackItem] {
        var valgusFrames: [Int] = []
        let kneeCaveThresholdRatio: CGFloat = 0.9 // If knee horizontal distance becomes < 90% of ankle distance, flag it. Tune this.

        for (index, framePoses) in poses.enumerated() {
            guard let lKnee = framePoses[lKneeIdx], let rKnee = framePoses[rKneeIdx],
                  let lAnkle = framePoses[lAnkleIdx], let rAnkle = framePoses[rAnkleIdx] else {
                continue // Skip frame if necessary points are missing
            }

            let kneeDistance = abs(lKnee.x - rKnee.x)
            let ankleDistance = abs(lAnkle.x - rAnkle.x)

            if ankleDistance > 0.01 && (kneeDistance / ankleDistance) < kneeCaveThresholdRatio {
                // Knee distance is significantly less than ankle distance
                valgusFrames.append(index)
            }
        }

        if !valgusFrames.isEmpty {
            // Find the frame with the most severe valgus (smallest ratio) or the one closest to the bottom/ascent
            // For simplicity, let's report the first occurrence during ascent if possible, or closest to bottom.
            let ascentStartIndex = bottomFrameIndex + 1
            let firstValgusOnAscent = valgusFrames.first(where: { $0 >= ascentStartIndex })
            let worstValgusFrame = firstValgusOnAscent ?? valgusFrames.last // Default to last detected if not on ascent

            if let frameIdx = worstValgusFrame {
                 print("Knee Valgus detected around frame \(frameIdx)")
                 return [FeedbackItem(type: .kneeValgus,
                                      message: "Knee Position: Avoid letting knees cave inward ('valgus'), especially when standing up. Push knees out over your feet.",
                                      frameIndex: frameIdx,
                                      timestamp: timestamps[safe: frameIdx])]
            }
        }

        return [] // No significant valgus detected
    }

    private func checkTorsoAngle(poses: [[CGPoint?]], bottomFrameIndex: Int, timestamps: [CMTime]) -> [FeedbackItem] {
        var feedback: [FeedbackItem] = []

        // --- Check 1: Excessive Forward Lean at the Bottom ---
        guard let bottomPose = poses[safe: bottomFrameIndex],
              let avgShoulder = averagePoint(p1: bottomPose[lShoulderIdx], p2: bottomPose[rShoulderIdx]),
              let avgHip = averagePoint(p1: bottomPose[lHipIdx], p2: bottomPose[rHipIdx]) else {
            print("Torso Check: Missing key joints at bottom frame.")
            return []
        }

        let torsoVector = CGPoint(x: avgShoulder.x - avgHip.x, y: avgShoulder.y - avgHip.y)
        let torsoAngleVertical = angleWithVertical(vector: torsoVector) // Angle from vertical (0 degrees = upright)

        let leanThreshold: CGFloat = 55.0 // Max angle from vertical (degrees). Tune this value. Closer to 90 is horizontal.
        print("Torso Check: Angle at bottom frame \(bottomFrameIndex) is \(torsoAngleVertical) degrees from vertical.")

        if torsoAngleVertical > leanThreshold {
             feedback.append(FeedbackItem(type: .torsoAngle,
                                          message: "Torso Angle: Excessive forward lean (\(Int(torsoAngleVertical))°) detected at the bottom. Keep your chest up and core braced.",
                                          frameIndex: bottomFrameIndex,
                                          timestamp: timestamps[safe: bottomFrameIndex]))
        }

        // --- Check 2: Change in Torso Angle (Rounding/Arching) during descent/ascent ---
        // Compare torso angle relative to thigh angle to detect significant changes
        var torsoThighAngleChanges: [(index: Int, change: CGFloat)] = []
        var previousRelativeAngle: CGFloat? = nil

        for (index, framePose) in poses.enumerated() {
             guard let shoulder = averagePoint(p1: framePose[lShoulderIdx], p2: framePose[rShoulderIdx]),
                   let hip = averagePoint(p1: framePose[lHipIdx], p2: framePose[rHipIdx]),
                   let knee = averagePoint(p1: framePose[lKneeIdx], p2: framePose[rKneeIdx]) else {
                 previousRelativeAngle = nil // Reset if joints missing
                 continue
             }

             let torsoVector = CGPoint(x: shoulder.x - hip.x, y: shoulder.y - hip.y)
             let thighVector = CGPoint(x: hip.x - knee.x, y: hip.y - knee.y) // Hip to Knee

             // Calculate angle between the two vectors
             let currentRelativeAngle = angleBetweenVectors(v1: torsoVector, v2: thighVector) // Angle ~0 if parallel, ~180 if opposite

             if let prevAngle = previousRelativeAngle {
                let change = abs(currentRelativeAngle - prevAngle)
                if change > 15.0 { // Detect significant change (>15 degrees frame-to-frame). Tune this threshold.
                     torsoThighAngleChanges.append((index: index, change: change))
                     print("Torso Check: Significant relative angle change (\(change)°) detected at frame \(index)")
                }
             }
             previousRelativeAngle = currentRelativeAngle
        }

        if let mostSignificantChange = torsoThighAngleChanges.max(by: { $0.change < $1.change }) {
             // Avoid adding duplicate feedback if lean was already excessive at bottom
             if !feedback.contains(where: {$0.type == .torsoAngle }) {
                 feedback.append(FeedbackItem(type: .torsoAngle,
                                              message: "Back Posture: Significant change in torso angle detected during movement. Aim to maintain a consistent, neutral spine.",
                                              frameIndex: mostSignificantChange.index,
                                              timestamp: timestamps[safe: mostSignificantChange.index]))
            }
        }


        return feedback
    }

    private func checkHeelLift(poses: [[CGPoint?]], timestamps: [CMTime]) -> [FeedbackItem] {
         var initialAnkleY: CGFloat? = nil
         var maxHeelLiftFrame: Int? = nil
         var maxLiftAmount: CGFloat = 0.0
         let liftThreshold: CGFloat = 0.02 // Normalized Y lift threshold (e.g., 2% of video height). Tune this.

         for (index, framePose) in poses.enumerated() {
             guard let lAnkle = framePose[lAnkleIdx], let rAnkle = framePose[rAnkleIdx] else {
                 continue // Skip if ankles not detected
             }
             let currentAvgAnkleY = (lAnkle.y + rAnkle.y) / 2.0

             if initialAnkleY == nil {
                 initialAnkleY = currentAvgAnkleY // Set baseline on first valid frame
             }

             if let initialY = initialAnkleY {
                 let liftAmount = currentAvgAnkleY - initialY // Y increases as you go up the screen
                 if liftAmount > liftThreshold && liftAmount > maxLiftAmount {
                     maxLiftAmount = liftAmount
                     maxHeelLiftFrame = index
                 }
             }
         }

         if let liftFrame = maxHeelLiftFrame {
             print("Heel lift detected at frame \(liftFrame), amount: \(maxLiftAmount)")
             return [FeedbackItem(type: .heelLift,
                                  message: "Heels: Heels lifted off the ground. Keep feet flat and pressure balanced.",
                                  frameIndex: liftFrame,
                                  timestamp: timestamps[safe: liftFrame])]
         }

         return []
     }

    private func checkAscentRate(poses: [[CGPoint?]], bottomFrameIndex: Int, frameDuration: CMTime?, timestamps: [CMTime]) -> [FeedbackItem] {
        guard let frameDur = frameDuration?.seconds, frameDur > 0, bottomFrameIndex + 2 < poses.count else {
            print("Ascent Check: Insufficient data for rate check.")
            return [] // Need at least 2 frames after bottom and frame duration
        }

        // Look at the first few frames of ascent (e.g., 2-3 frames after bottom)
        let ascentStartIdx = bottomFrameIndex + 1
        let ascentEndIdx = min(bottomFrameIndex + 3, poses.count - 1) // Check 2-3 frames up

        guard let startPose = poses[safe: ascentStartIdx],
              let endPose = poses[safe: ascentEndIdx],
              let startHipY = averagePoint(p1: startPose[lHipIdx], p2: startPose[rHipIdx])?.y,
              let endHipY = averagePoint(p1: endPose[lHipIdx], p2: endPose[rHipIdx])?.y,
              let startShoulderY = averagePoint(p1: startPose[lShoulderIdx], p2: startPose[rShoulderIdx])?.y,
              let endShoulderY = averagePoint(p1: endPose[lShoulderIdx], p2: endPose[rShoulderIdx])?.y
               else {
            print("Ascent Check: Missing joints during ascent phase.")
            return []
        }

        let timeElapsed = Double(ascentEndIdx - ascentStartIdx) * frameDur
        guard timeElapsed > 0 else { return [] }

        // Calculate vertical velocity (change in Y / time). Higher Y is top of screen.
        // Upward movement means Y increases. Velocity will be positive.
        let hipVelocity = (endHipY - startHipY) / CGFloat(timeElapsed)
        let shoulderVelocity = (endShoulderY - startShoulderY) / CGFloat(timeElapsed)

        // Check if hip velocity is significantly greater than shoulder velocity
        let velocityRatioThreshold: CGFloat = 1.5 // If hips move > 1.5x faster than shoulders. Tune this.

        print("Ascent Check: Hip Velocity ≈ \(hipVelocity), Shoulder Velocity ≈ \(shoulderVelocity)")

        if hipVelocity > shoulderVelocity * velocityRatioThreshold && shoulderVelocity > 0 { // Ensure movement is upwards
            print("Ascent Check: Hips rising significantly faster than shoulders at frame \(ascentStartIdx)")
             return [FeedbackItem(type: .ascentRate,
                                  message: "Ascent: Hips are rising much faster than shoulders. Drive up with chest and hips together.",
                                  frameIndex: ascentStartIdx,
                                  timestamp: timestamps[safe: ascentStartIdx])]
        }

        return []
    }


    // --- Angle Calculation Helpers ---

    // Calculates angle between p1-p2 and p3-p2 (angle at p2)
    private func calculateAngle(p1: CGPoint?, p2: CGPoint?, p3: CGPoint?) -> CGFloat? {
        guard let p1 = p1, let p2 = p2, let p3 = p3 else { return nil }
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        let angle1 = atan2(v1.y, v1.x)
        let angle2 = atan2(v2.y, v2.x)
        var angle = angle1 - angle2
        // Normalize angle to be between 0 and 2*pi
        while angle < 0 { angle += .pi * 2 }
        while angle >= .pi * 2 { angle -= .pi * 2 }
        // Convert to degrees (0-360)
        let degrees = angle * 180.0 / .pi
        // Often we want the smaller interior angle (0-180)
        return min(degrees, 360.0 - degrees)
    }

    // Helper to calculate angle based on joint indices in a pose array
    private func calculateAngle(p1Idx: Int, p2Idx: Int, p3Idx: Int, pose: [CGPoint?]) -> CGFloat? {
         return calculateAngle(p1: pose[safe: p1Idx] ?? nil,
                               p2: pose[safe: p2Idx] ?? nil,
                               p3: pose[safe: p3Idx] ?? nil)
    }

    // Calculates angle between two vectors
    private func angleBetweenVectors(v1: CGPoint, v2: CGPoint) -> CGFloat {
         let dotProduct = v1.x * v2.x + v1.y * v2.y
         let magnitudeV1 = sqrt(v1.x * v1.x + v1.y * v1.y)
         let magnitudeV2 = sqrt(v2.x * v2.x + v2.y * v2.y)

         guard magnitudeV1 > 0 && magnitudeV2 > 0 else { return 0 } // Avoid division by zero

         let cosTheta = dotProduct / (magnitudeV1 * magnitudeV2)
        // Clamp cosTheta to avoid floating point errors outside [-1, 1] range
         let clampedCosTheta = max(-1.0, min(1.0, cosTheta))

         let angleRadians = acos(clampedCosTheta)
         return angleRadians * 180.0 / .pi // Return angle in degrees
     }

    // Calculates the angle of a vector relative to the positive Y-axis (vertical upward)
    // Returns angle in degrees (0 = straight up, 90 = horizontal right, 180 = straight down, 270 = horizontal left)
    private func angleWithVertical(vector: CGPoint) -> CGFloat {
        guard vector.x != 0 || vector.y != 0 else { return 0 }
        // atan2(x, y) gives angle from positive Y axis, clockwise positive
        let angleRadians = atan2(vector.x, vector.y)
        var angleDegrees = angleRadians * 180.0 / .pi
        // Convert from (-180, 180] to [0, 360)
        if angleDegrees < 0 {
            angleDegrees += 360.0
        }
         // We often care about the angle relative to upright (0 degrees) or downright (180 degrees)
         // For lean, let's measure deviation from vertical (0 or 180).
         // Return the smaller angle relative to the vertical axis (0-180 range)
         return min(angleDegrees, 360.0 - angleDegrees)

     }


    // --- Utility Helpers ---

    // Safely access array elements
     private func safeGetPoint(from pose: [CGPoint?], at index: Int) -> CGPoint? {
         guard pose.indices.contains(index) else { return nil }
         return pose[index]
     }

    // Calculate average point between two optional points
    private func averagePoint(p1: CGPoint?, p2: CGPoint?) -> CGPoint? {
        if let p1 = p1, let p2 = p2 {
            return CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
        } else {
            return p1 ?? p2 // Return whichever one is not nil, or nil if both are
        }
    }
}

// Helper extension for safe array access
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Helper for CMTime to get seconds safely
extension CMTime {
    var seconds: Double? {
        let seconds = CMTimeGetSeconds(self)
        return seconds.isNaN ? nil : seconds
    }
}
