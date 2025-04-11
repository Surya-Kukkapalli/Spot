import AVFoundation
import Vision
import UIKit // Needed for UIImage, CGPoint calculations

class PoseAnalyzer {

    // Main function to analyze the video at the given URL
    // Throws errors if video reading or processing fails
    // Uses 'async' to indicate it's an asynchronous function
    func analyzeSquatVideo(url: URL) async throws -> [String] {

        // 1. Read video frames using AVFoundation
        let frameData = try await readVideoFrames(url: url)

        // 2. Perform Pose Estimation on each frame using Vision
        var allFramePoses: [[CGPoint?]] = [] // Store detected joint points for each frame
        for frame in frameData.pixelBuffers {
            let posePoints = try await performPoseEstimation(on: frame)
            allFramePoses.append(posePoints)
        }

        // If no poses were detected at all, return early
        guard !allFramePoses.isEmpty else {
            return ["Could not detect any poses in the video."]
        }

        // 3. Analyze the sequence of poses to evaluate squat form
        let feedback = analyzeSquatForm(poses: allFramePoses, frameTimestamps: frameData.timestamps)

        return feedback
    }

    // --- Helper: Reading Video Frames ---

    // Structure to hold frame pixel buffer and its timestamp
    private struct FrameData {
        let pixelBuffers: [CVPixelBuffer]
        let timestamps: [CMTime]
    }

    // Reads a video file and extracts CVPixelBuffer frames and their timestamps
    private func readVideoFrames(url: URL) async throws -> FrameData {
        let asset = AVURLAsset(url: url) // Represents the video file

        // Check if the video track is readable
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "PoseAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        // Get video properties like size and duration
        let videoSize = try await track.load(.naturalSize)
        let duration = try await asset.load(.duration)
        let frameRate = try await track.load(.nominalFrameRate) // Approximate frame rate
        print("Video duration: \(CMTimeGetSeconds(duration)), Frame rate: \(frameRate)")


        // Setup AVAssetReader to read video frames
        let reader = try AVAssetReader(asset: asset)
        // Define the output format: uncompressed video frames (BGRA)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)

        // Check if output can be added to reader
         guard reader.canAdd(readerOutput) else {
             throw NSError(domain: "PoseAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add reader output"])
         }
        reader.add(readerOutput)

        // Start reading
        guard reader.startReading() else {
             throw NSError(domain: "PoseAnalyzer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start reading video"])
         }


        var pixelBuffers: [CVPixelBuffer] = []
        var timestamps: [CMTime] = []

        // Loop through the video frames
        while reader.status == .reading {
            // Get the next available frame sample buffer
            if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
               // Extract the pixel buffer (the actual image data)
               let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                // Get the timestamp of the frame
                 let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                pixelBuffers.append(pixelBuffer)
                timestamps.append(timestamp)
                // Release the sample buffer when done with it
                // CMSampleBufferInvalidate(sampleBuffer) // Usually managed automatically with ARC, but can be explicit
            } else if reader.status == .completed {
                 // End of video
                 break
            } else if reader.status == .failed {
                // Handle reader errors
                print("Reader failed with error: \(reader.error?.localizedDescription ?? "Unknown error")")
                throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
            }
            // Add a small sleep to prevent tight loop if needed (optional)
             try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
        }

        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "PoseAnalyzer", code: 4, userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"])
        }

        print("Successfully read \(pixelBuffers.count) frames.")
        return FrameData(pixelBuffers: pixelBuffers, timestamps: timestamps)
    }


    // --- Helper: Performing Pose Estimation ---

    // Performs Vision human body pose request on a single CVPixelBuffer
    private func performPoseEstimation(on pixelBuffer: CVPixelBuffer) async throws -> [CGPoint?] {
        // Create a Vision request for detecting human body poses
        let request = VNDetectHumanBodyPoseRequest()

        // Create a request handler for the single image (pixel buffer)
        // Ensure orientation matches the video's orientation if possible, otherwise `.up` is a common default.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        // Perform the request asynchronously
        // Use a Task to ensure this runs correctly in an async context if needed,
        // although handler.perform itself can throw and might not need explicit Task wrapping here.
        try handler.perform([request]) // Simpler call

        // Define the specific joints we need *before* checking results
        let neededJoints: [VNHumanBodyPoseObservation.JointName] = [
            .root, // Center of hips estimate
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .leftShoulder, .rightShoulder
            // Add more if needed (e.g., .neck, .nose for head position)
        ]

        // Get the results (observations)
        guard let observation = request.results?.first // Use optional chaining and grab the first result
        else {
            // No pose detected in this frame. Return an array of nils matching the neededJoints count.
            print("Warning: No pose observation found in this frame.")
            // Return an array with nil for each joint we were looking for.
            return Array(repeating: nil, count: neededJoints.count)
            // *** REMOVED THE LINE CAUSING THE ERROR ***
        }


        // Extract the recognized points (joints)
        // We get normalized coordinates (0.0 to 1.0) relative to the image dimensions
        var framePoints: [CGPoint?] = []
        // Get all points recognized in this observation
        let recognizedPoints = try observation.recognizedPoints(.all)

        // Iterate through the joints *we* defined as needed
        for jointName in neededJoints {
            // Check if this specific joint exists in the recognized points and meets confidence threshold
            if let point = recognizedPoints[jointName], point.confidence > 0.1 { // Only consider points with some confidence
                // Vision returns points with origin at bottom-left.
                // Use point.location which is already a CGPoint
                framePoints.append(point.location)
            } else {
                framePoints.append(nil) // Joint not detected or low confidence
            }
        }

        // The framePoints array now directly corresponds to the neededJoints array order.
        return framePoints
    }

    // --- Helper: Analyzing Squat Form (This is where rules go!) ---

    // Analyzes the sequence of poses based on simple rules
    // Input: poses - Array where each element is an array of optional CGPoints for joints in a single frame
    // Input: frameTimestamps - Array of CMTime for each frame
    // Output: Array of feedback strings
    private func analyzeSquatForm(poses: [[CGPoint?]], frameTimestamps: [CMTime]) -> [String] {
        var feedback: [String] = []

        // --- Basic Checks ---
        guard !poses.isEmpty else { return ["No pose data to analyze."] }

        // --- Define Joint Indices based on 'neededJoints' order in performPoseEstimation ---
        let rootIdx = 0
        let lHipIdx = 1, rHipIdx = 2
        let lKneeIdx = 3, rKneeIdx = 4
        let lAnkleIdx = 5, rAnkleIdx = 6
        let lShoulderIdx = 7, rShoulderIdx = 8

        // --- Rule 1: Check Squat Depth ---
        var minHipKneeRatio: CGFloat = 1.0 // Start assuming hips never went below knees
        var lowestPointFrameIndex: Int? = nil

        for (index, framePoses) in poses.enumerated() {
            // Need hip and knee points on at least one side to estimate depth
            guard let hipY = framePoses[lHipIdx]?.y ?? framePoses[rHipIdx]?.y,
                  let kneeY = framePoses[lKneeIdx]?.y ?? framePoses[rKneeIdx]?.y else {
                continue // Skip frame if essential points are missing
            }

            // Simple vertical comparison (remember Vision's origin is bottom-left)
            // Lower Y value means higher on the screen. HipY < KneeY means hip is above knee.
             let currentRatio = hipY / kneeY // A rough ratio, assumes kneeY is not zero
             if currentRatio < minHipKneeRatio {
                 minHipKneeRatio = currentRatio
                 lowestPointFrameIndex = index
             }

            // Alternative: Calculate vertical distance relative to ankle?
            // Might be more robust if user isn't perfectly centered.
            // Needs ankle points too.
        }

        // Threshold for good depth (e.g., hips roughly level with or below knees)
        // A hipY slightly less than kneeY (e.g., 0.95 * kneeY) could mean parallel.
        // This threshold needs tuning! Let's say hipY < 1.0 * kneeY is acceptable depth.
        // Our ratio minHipKneeRatio needs to be <= 1.0 for hips level or below knees.
        if minHipKneeRatio > 1.05 { // Add a small tolerance
            feedback.append("Squat Depth: Try to go lower. Aim for your hips to be at least level with your knees.")
        } else {
             feedback.append("Squat Depth: Looks reasonable.")
         }


        // --- Rule 2: Check Knee Position (Simplified - Forward Movement) ---
        // This is hard in 2D! A true check needs side view or 3D.
        // We can *roughly* check if knees move excessively forward relative to ankles *at the bottom*.
        if let bottomFrameIndex = lowestPointFrameIndex, poses.indices.contains(bottomFrameIndex) {
             let bottomPoses = poses[bottomFrameIndex]
            if let kneeX = bottomPoses[lKneeIdx]?.x ?? bottomPoses[rKneeIdx]?.x,
               let ankleX = bottomPoses[lAnkleIdx]?.x ?? bottomPoses[rAnkleIdx]?.x {
                // This assumes a front-facing view. If knee X is significantly different
                // from ankle X, it might indicate caving in/out, OR forward travel.
                // A better check might involve angles.
                // Let's just add a placeholder comment for now.
                // feedback.append("Knee Position: Check if knees track over toes (cannot verify accurately from this angle).")
            }
             // Add more advanced checks below if needed.
        }


        // --- Rule 3: Check Back Angle (Simplified - Upright Torso) ---
        // Compare vertical position of shoulders vs hips at the bottom.
         if let bottomFrameIndex = lowestPointFrameIndex, poses.indices.contains(bottomFrameIndex) {
             let bottomPoses = poses[bottomFrameIndex]
            if let shoulderY = bottomPoses[lShoulderIdx]?.y ?? bottomPoses[rShoulderIdx]?.y,
               let hipY = bottomPoses[lHipIdx]?.y ?? bottomPoses[rHipIdx]?.y {
                // If shoulders are significantly lower than a certain threshold above hips,
                // the torso might be leaning too far forward.
                // Threshold depends on squat type (high bar vs low bar).
                // Let's say shoulderY should be significantly > hipY.
                // e.g., if shoulderY < hipY * 1.2 (arbitrary threshold - needs tuning!)
                 if shoulderY < hipY * 1.1 { // Very rough check
                     feedback.append("Torso Angle: Try to keep your chest up more; avoid leaning too far forward.")
                 } else {
                     feedback.append("Torso Angle: Seems okay.")
                 }
            }
        }


        // --- Rule 4 (Example): Check if Pose was Detected ---
        let framesWithPoses = poses.filter { frame in frame.compactMap { $0 }.count > 4 }.count // Count frames with at least 4 valid joints
        if Double(framesWithPoses) / Double(poses.count) < 0.5 { // If less than 50% of frames had a decent pose
            feedback.append("Detection Quality: Could not reliably detect pose in large parts of the video. Ensure good lighting and full body visibility.")
        }


        // **FUTURE:** Calculate angles (e.g., knee angle, hip angle, back angle)
        // Use `atan2` function with joint coordinates to find angles between body segments.
        // Compare these angles against known "good" ranges (potentially from your CSV).

        return feedback
    }


     // --- Angle Calculation Helper (Example) ---
     // Calculates the angle between three points (p2 is the vertex)
     func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
         let v1 = (x: p1.x - p2.x, y: p1.y - p2.y)
         let v2 = (x: p3.x - p2.x, y: p3.y - p2.y)
         let angle1 = atan2(v1.y, v1.x)
         let angle2 = atan2(v2.y, v2.x)
         var angle = angle1 - angle2
         // Ensure angle is positive
         while angle < 0 { angle += .pi * 2 }
         // Convert to degrees
         return angle * 180.0 / .pi
     }
}
