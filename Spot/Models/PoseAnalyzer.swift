import AVFoundation
import Vision
import UIKit // Needed for UIImage, CGPoint calculations
import CoreImage // For CIContext

// New struct to hold feedback and associated frame info
struct FeedbackItem: Hashable { // Hashable needed for ForEach identifier
    let id = UUID() // Unique ID for list iteration
    let message: String
    let frameIndex: Int? // Index of the frame where the issue was most prominent
    let timestamp: CMTime? // Timestamp of that frame

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


    // Main analysis function now returns [FeedbackItem]
    func analyzeSquatVideo(url: URL) async throws -> [FeedbackItem] { // <--- Changed return type

        // --- Debugging ---
        print("Starting analysis for video: \(url.lastPathComponent)")
        // ---
        
        // Prepare the image generator for frame fetching later
        let asset = AVURLAsset(url: url)
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.appliesPreferredTrackTransform = true // Handle video rotation
        imageGenerator?.requestedTimeToleranceBefore = .zero
        imageGenerator?.requestedTimeToleranceAfter = .zero

        // 1. Read video frames using AVFoundation
        let frameData = try await readVideoFrames(url: url)

        // Check if frames were read
        guard !frameData.pixelBuffers.isEmpty else {
             imageGenerator = nil // Clean up
            // --- Debugging ---
            print("Analysis stopped: No frames read from video.")
            // ---
             return [FeedbackItem(message: "Could not read any frames from the video.", frameIndex: nil, timestamp: nil)]
        }
        // --- Debugging ---
        print("Read \(frameData.pixelBuffers.count) frames. Starting pose estimation...")
        // ---

        // 2. Perform Pose Estimation on each frame
        var allFramePoses: [[CGPoint?]] = []
        for (index, frame) in frameData.pixelBuffers.enumerated() {
            // --- Debugging ---
            // Print progress occasionally to avoid spamming console for long videos
            if index % 10 == 0 || index == frameData.pixelBuffers.count - 1 {
                print("  Processing frame \(index + 1)/\(frameData.pixelBuffers.count)...")
            }
            // ---
            do {
                let posePoints = try await performPoseEstimation(on: frame)
                allFramePoses.append(posePoints)
            } catch {
                // --- Debugging ---
                print("  Error during pose estimation for frame \(index): \(error.localizedDescription). Skipping frame.")
                // ---
                 // Append nils to keep frame count consistent if needed, or handle differently
                 allFramePoses.append(Array(repeating: nil, count: 9)) // Assuming 9 needed joints
            }
        }
        
        // --- Debugging ---
        print("Finished processing all frames. Checking results...")
        let totalFrames = allFramePoses.count
        let nonNilCounts = allFramePoses.map { $0.compactMap { $0 }.count }
        let framesWithAnyPoses = nonNilCounts.filter { $0 > 0 }.count
        let maxJointsInFrame = nonNilCounts.max() ?? 0
        print("  - Total frames processed: \(totalFrames)")
        print("  - Frames with at least 1 joint detected: \(framesWithAnyPoses) / \(totalFrames)")
        print("  - Max joints detected in any single frame: \(maxJointsInFrame)")
        if totalFrames > 0 && framesWithAnyPoses == 0 {
             print("  - DETAILED CHECK: No joints detected in ANY frame.")
        } else if totalFrames > 0 {
            let avgJoints = Double(nonNilCounts.reduce(0, +)) / Double(framesWithAnyPoses > 0 ? framesWithAnyPoses : 1) // Avoid division by zero
             print("  - Avg joints per frame (where detected): \(String(format: "%.1f", avgJoints))")
        }
        // ---


//        // If no poses were detected at all, return early
//        guard !allFramePoses.contains(where: { !$0.compactMap { $0 }.isEmpty }) else {
//             imageGenerator = nil // Clean up
//            return [FeedbackItem(message: "Could not detect any poses in the video.", frameIndex: nil, timestamp: nil)]
//        }
        
        // The Guard Check (using the debugging info just calculated)
        guard framesWithAnyPoses > 0 else {
            imageGenerator = nil
            print("Error Check Triggered: Found 0 frames with any detected poses meeting confidence threshold.") // Debugging
            return [FeedbackItem(message: "Could not detect any poses in the video.", frameIndex: nil, timestamp: nil)]
        }

        // --- Debugging ---
        print("Pose data found (\(framesWithAnyPoses) frames). Proceeding to analyzeSquatForm.")
        // ---
        // 3. Analyze the sequence of poses to evaluate squat form
        // Pass frame data (indices/timestamps) to the analysis function
        let feedback = analyzeSquatForm(poses: allFramePoses, frameData: frameData)

        // Don't cleanup imageGenerator here if feedback might need it later.
        // Clean it up in the ViewModel when analysis is done or a new video is loaded.

        return feedback
    }

    // Function to fetch a specific frame as UIImage using the cached generator
    func fetchFrameImage(at time: CMTime) async -> UIImage? {
        guard let generator = imageGenerator else { return nil }
        do {
            // Generate CGImage first
            let cgImage = try await generator.copyCGImage(at: time, actualTime: nil)
            // Convert CGImage to UIImage
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating frame image at time \(CMTimeGetSeconds(time)): \(error)")
            return nil
        }
    }
    
    // Function to fetch a frame as CVPixelBuffer (more efficient if needed for redraw)
    // NOTE: AVAssetImageGenerator primarily gives CGImage. For CVPixelBuffer,
    // re-reading with AVAssetReader at a specific time range might be needed,
    // or render the CGImage to a CVPixelBuffer if required. Let's stick to UIImage for now.


    // Clean up the image generator when no longer needed
    func cleanupGenerator() {
        imageGenerator = nil
    }


    // --- Helper: Reading Video Frames (Keep FrameData struct) ---
    private struct FrameData {
        let pixelBuffers: [CVPixelBuffer]
        let timestamps: [CMTime]
        let videoSize: CGSize // Store video size if needed for coordinate scaling
    }

    private func readVideoFrames(url: URL) async throws -> FrameData {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "PoseAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        let videoSize = try await track.load(.naturalSize)
        let duration = try await asset.load(.duration)
        // ... rest of the frame reading logic as before ...
        // Ensure it returns FrameData(pixelBuffers: pixelBuffers, timestamps: timestamps, videoSize: videoSize)
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
             } else if reader.status == .completed {
                  break
             } else if reader.status == .failed {
                 print("Reader failed with error: \(reader.error?.localizedDescription ?? "Unknown error")")
                 throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
             }
              try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
         }
         if reader.status == .failed {
             throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
         }
         print("Successfully read \(pixelBuffers.count) frames.")
         return FrameData(pixelBuffers: pixelBuffers, timestamps: timestamps, videoSize: videoSize) // Make sure to return FrameData
    }

    // --- Helper: Performing Pose Estimation  ---
    private func performPoseEstimation(on pixelBuffer: CVPixelBuffer) async throws -> [CGPoint?] {
         let request = VNDetectHumanBodyPoseRequest()
         let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        // --- Debugging ---
        // print("  Performing Vision request for one frame...") // Can be too verbose, enable if needed
        // ---
 
        // It's slightly better practice to perform sync Vision tasks within Task {}
        // if called from an async context, though handler.perform often blocks appropriately.
         try handler.perform([request])
        
         let neededJoints: [VNHumanBodyPoseObservation.JointName] = [
             .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftShoulder, .rightShoulder
         ]
         guard let observation = request.results?.first else {
             // --- Debugging ---
             // This message will print if Vision finds NO pose at all in the frame
             // print("    - Vision found no pose observation in this frame.") // Can be verbose
             // ---
             return Array(repeating: nil, count: neededJoints.count)
         }
        
        // --- Debugging ---
        // print("    - Vision found pose observation. Checking joints...") // Verbose
        var detectedPointsInfo: [String] = []
        var lowConfidenceCount = 0
        var foundCount = 0
        // ---

         var framePoints: [CGPoint?] = []
         let recognizedPoints = try observation.recognizedPoints(.all)
        
        for jointName in neededJoints {
            if let point = recognizedPoints[jointName] {
                let confidence = point.confidence
                // --- Debugging ---
                // Only log if confidence is low but point exists
                // if confidence <= 0.1 {
                //     detectedPointsInfo.append("\(jointName.rawValue): Conf \(String(format: "%.2f", confidence))")
                //     lowConfidenceCount += 1
                // }
                // ---
                if confidence > 0.1 {
                    framePoints.append(point.location)
                    foundCount += 1 // Debugging
                } else {
                    framePoints.append(nil) // Low confidence
                }
            } else {
                framePoints.append(nil) // Not detected
            }
        }

        // --- Debugging ---
        // Print summary only if interesting (e.g., some points found but none met threshold)
        // if foundCount == 0 && recognizedPoints.count > 0 {
        //      print("    - Frame Summary: Points recognized but none met confidence > 0.1. Low Confs: \(lowConfidenceCount). Details: [\(detectedPointsInfo.joined(separator: ", "))]")
        // } else if foundCount > 0 {
        //      // print("    - Frame Summary: Found \(foundCount) points meeting confidence.") // Verbose
        // }
        // ---
        
//        for jointName in neededJoints {
//            if let point = recognizedPoints[jointName], point.confidence > 0.1 {
//                framePoints.append(point.location)
//            } else {
//                framePoints.append(nil)
//            }
//        }
        return framePoints
    }


    // --- Helper: Analyzing Squat Form ---
    // Now takes FrameData and returns [FeedbackItem]
    private func analyzeSquatForm(poses: [[CGPoint?]], frameData: FrameData) -> [FeedbackItem] { // <--- Changed parameters and return type
        var feedback: [FeedbackItem] = [] // <--- Changed type

        guard !poses.isEmpty else { return [FeedbackItem(message: "No pose data to analyze.", frameIndex: nil, timestamp: nil)] }

        let timestamps = frameData.timestamps // Extract timestamps

        // --- Define Joint Indices ---
        let rootIdx = 0, lHipIdx = 1, rHipIdx = 2, lKneeIdx = 3, rKneeIdx = 4
        let lAnkleIdx = 5, rAnkleIdx = 6, lShoulderIdx = 7, rShoulderIdx = 8

        // --- Rule 1: Check Squat Depth ---
        var minHipKneeRatio: CGFloat = 2.0 // Initialize higher
        var lowestPointFrameIndex: Int? = nil

        for (index, framePoses) in poses.enumerated() {
            guard let hipY = framePoses[lHipIdx]?.y ?? framePoses[rHipIdx]?.y,
                  let kneeY = framePoses[lKneeIdx]?.y ?? framePoses[rKneeIdx]?.y, kneeY > 0 else {
                continue // Skip frame if essential points missing or kneeY is zero
            }
            let currentRatio = hipY / kneeY
            if currentRatio < minHipKneeRatio {
                 minHipKneeRatio = currentRatio
                 lowestPointFrameIndex = index
            }
        }

        let depthThreshold: CGFloat = 0.65 // Hips slightly below knees (adjust!)
        if let idx = lowestPointFrameIndex, minHipKneeRatio > depthThreshold {
            // Associated the feedback with the frame index and timestamp where depth was shallowest
            feedback.append(FeedbackItem(message: "Squat Depth: Try to go lower. Aim for getting your hips below your knees.",
                                         frameIndex: idx,
                                         timestamp: timestamps.indices.contains(idx) ? timestamps[idx] : nil))
        } else if lowestPointFrameIndex != nil {
             feedback.append(FeedbackItem(message: "Squat Depth: Great job hitting depth!", frameIndex: lowestPointFrameIndex, timestamp: timestamps.indices.contains(lowestPointFrameIndex!) ? timestamps[lowestPointFrameIndex!] : nil))
        }


        // --- Rule 3: Check Back Angle (Simplified - Upright Torso) ---
         var minShoulderHipRatio: CGFloat = 2.0 // Initialize higher
         var mostLeanedFrameIndex: Int? = nil

         // Find the frame with the most forward lean (lowest shoulder relative to hip) at/near the bottom
         // Let's refine this: Find the lowest point first (lowest hip Y)
         var lowestHipY: CGFloat = 0.0 // Vision Y=0 is bottom
         var actualBottomFrameIndex: Int? = nil
         for (index, framePoses) in poses.enumerated() {
             if let hipY = framePoses[rootIdx]?.y ?? framePoses[lHipIdx]?.y ?? framePoses[rHipIdx]?.y {
                  if actualBottomFrameIndex == nil || hipY < lowestHipY {
                      lowestHipY = hipY
                      actualBottomFrameIndex = index
                  }
             }
         }


        // Now check torso angle at that bottom frame
        if let idx = actualBottomFrameIndex, poses.indices.contains(idx) {
            let bottomPoses = poses[idx]
            if let shoulderY = bottomPoses[lShoulderIdx]?.y ?? bottomPoses[rShoulderIdx]?.y,
               let hipY = bottomPoses[rootIdx]?.y ?? bottomPoses[lHipIdx]?.y ?? bottomPoses[rHipIdx]?.y, hipY > 0 {
                let shoulderHipRatio = shoulderY / hipY
                let leanThreshold: CGFloat = 1.15 // Shoulder Y should be at least 1.15x Hip Y (tune this!)
                if shoulderHipRatio < leanThreshold {
                    feedback.append(FeedbackItem(message: "Torso Angle: Avoid leaning too far forward at the bottom.",
                                                 frameIndex: idx,
                                                 timestamp: timestamps.indices.contains(idx) ? timestamps[idx] : nil))
                } else {
                     feedback.append(FeedbackItem(message: "Torso Angle: Looks great, nice job engaging that core.", frameIndex: idx, timestamp: timestamps.indices.contains(idx) ? timestamps[idx] : nil))
                 }
            }
        }


        // --- Rule 4: Detection Quality ---
        let framesWithPoses = poses.filter { frame in frame.compactMap { $0 }.count >= 4 }.count
        if Double(framesWithPoses) / Double(poses.count) < 0.5 {
             feedback.append(FeedbackItem(message: "Detection Quality: Low confidence. Ensure good lighting & visibility.", frameIndex: nil, timestamp: nil))
        }

        // Return the structured feedback
        return feedback
    }

    // --- Angle Calculation Helper (Keep as before) ---
     func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        // ... same implementation ...
         let v1 = (x: p1.x - p2.x, y: p1.y - p2.y)
         let v2 = (x: p3.x - p2.x, y: p3.y - p2.y)
         let angle1 = atan2(v1.y, v1.x)
         let angle2 = atan2(v2.y, v2.x)
         var angle = angle1 - angle2
         while angle < 0 { angle += .pi * 2 }
         return angle * 180.0 / .pi
     }
}
