// VisionView.swift
// NOW INCLUDES UI FOR LIVE CAMERA + VIDEO UPLOAD MODES

import SwiftUI
import PhotosUI
import AVKit
import Vision

struct VisionView: View {
    @StateObject private var viewModel = VisionViewModel()
    @Environment(\.colorScheme) var colorScheme // For dynamic background

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // --- Mode Selector ---
                    modeSelectorView()
                        .padding(.top)

                    // --- Conditional UI based on Mode ---
                    if viewModel.currentMode == .videoUpload {
                        videoUploadInterface(geometry: geometry)
                    } else { // .liveCamera
                        liveCameraInterface(geometry: geometry)
                    }

                    // --- Common Status Message ---
                    statusMessageView() // Shows general status

                    // --- Common Feedback List (for video summary or live session summary) ---
//                    commonFeedbackDisplayView()
//                        .frame(height: 200) // Temporary for testing
//                        .background(Color.yellow) // Temporary for testing

                    Spacer()
                }
                .padding(.bottom)
                .frame(minHeight: geometry.size.height) // Ensure content can fill screen
            }
            .sheet(isPresented: $viewModel.showLiveSummarySheet) {
                // wrap commonFeedbackDisplayView in a NavigationView for a title
                NavigationView {
                    commonFeedbackDisplayView() // This will now be presented in a sheet
                        .navigationTitle(viewModel.currentMode == .videoUpload ? "Video Summary" : "Live Session Summary")
                        .navigationBarItems(trailing: Button("Done") {
                            viewModel.showLiveSummarySheet = false
                        })
                }
            }
        }
        .navigationTitle("Form Analyzer")
        .background(Color(.systemGroupedBackground).ignoresSafeArea(.all, edges: .bottom))
        .sheet(item: $viewModel.selectedFeedbackItem) { itemToShowInSheet in
            // Use the FeedbackDetailWrapperView here as well for consistency.
            // This 'itemToShowInSheet' comes from whatever viewModel.selectedFeedbackItem was set to.
            FeedbackDetailWrapperView(item: itemToShowInSheet, viewModel: viewModel)
        }
        .onDisappear {
            viewModel.cleanupResources() // Cleanup when view disappears
        }
        .alert("Alert", isPresented: $viewModel.showErrorAlert, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        // Request camera permission when live mode is first selected or view appears if default is live
        .onAppear {
            if viewModel.currentMode == .liveCamera {
                viewModel.checkCameraPermission()
            }
        }
    }

    // MARK: - Mode Selector View
    @ViewBuilder
    private func modeSelectorView() -> some View {
        Picker("Analysis Mode", selection: $viewModel.currentMode) {
            Text("Upload Video").tag(VisionViewModel.AnalysisMode.videoUpload)
            Text("Live Session").tag(VisionViewModel.AnalysisMode.liveCamera)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: viewModel.currentMode) { newMode in
            viewModel.switchMode(to: newMode)
        }
    }

    // MARK: - Video Upload Specific UI
    @ViewBuilder
    private func videoUploadInterface(geometry: GeometryProxy) -> some View {
        // (Reusing your existing videoPlayerView and placeholderView for video upload)
        videoPlayerPreview() // Shows AVPlayer for selected video
            .padding(.top)

        videoUploadControlButtons()
            .padding(.bottom, 5)
    }

    @ViewBuilder
    private func videoPlayerPreview() -> some View { // Renamed from videoPlayerView
        Group {
            if let player = viewModel.videoPlayer, viewModel.currentMode == .videoUpload {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(height: 250) // Consistent height
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else if viewModel.currentMode == .videoUpload { // Show placeholder only in video upload mode if no video
                videoUploadPlaceholderView()
            }
        }
    }

    @ViewBuilder
    private func videoUploadPlaceholderView() -> some View { // Renamed from placeholderView
        // (Your existing placeholderView from VisionView.txt source: 173-175)
        VStack(spacing: 15) {
            Image(systemName: "figure.squat")
                .resizable().scaledToFit().frame(height: 70)
                .foregroundColor(.accentColor.opacity(0.8))
            Text("Select Squat Video for Upload")
                .font(.headline).foregroundColor(.primary)
            Text("Select a video of your squat for form analysis and feedback.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(height: 250).frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func videoUploadControlButtons() -> some View { // Renamed from controlButtonsView
        // (Your existing controlButtonsView from VisionView.txt source: 176-181,
        //  but ensure disable conditions check viewModel.currentMode == .videoUpload)
        VStack(spacing: 12) {
            PhotosPicker(selection: $viewModel.selectedVideoItem, matching: .videos) {
                 Label("Select Video", systemImage: "video.badge.plus")
                     .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(.accentColor)
            .disabled(viewModel.isProcessing || viewModel.currentMode != .videoUpload)
            .padding(.horizontal)

            Button {
                viewModel.startVideoAnalysis()
            } label: {
                if viewModel.isProcessing && viewModel.currentMode == .videoUpload {
                    HStack(spacing: 10) { ProgressView().tint(colorScheme == .dark ? .white : .black); Text("Analyzing Video...") }
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                } else {
                    Label("Analyze Uploaded Squat", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.videoURL == nil || viewModel.isProcessing || viewModel.currentMode != .videoUpload)
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isProcessing)
        }
    }

    // MARK: - Live Camera Specific UI
    @ViewBuilder
    private func liveCameraInterface(geometry: GeometryProxy) -> some View {
        ZStack { // Use ZStack to overlay loading indicator
            if viewModel.isCameraPermissionGranted {
                CameraPreviewView(captureSession: viewModel.captureSession)
                    .frame(height: geometry.size.width * (16/9)) // Maintain aspect ratio, adjust as needed
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .overlay( // For skeleton drawing
                        PoseOverlayView(posePoints: viewModel.livePoseOverlayPoints)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

            } else {
                liveCameraPermissionPlaceholderView()
            }
            
            // Live Feedback Text Overlay
            VStack {
                Spacer() // Pushes to bottom
                if let liveFeedback = viewModel.currentLiveFeedback, viewModel.isLiveSessionRunning {
                    Text("\(liveFeedback.type.rawValue): \(liveFeedback.message)")
                        .font(.caption.weight(.medium))
                        .padding(8)
                        .background(Material.thick) // Use material for nice background
                        .clipShape(Capsule())
                        .foregroundColor(feedbackTextColor(for: liveFeedback.type))
                        .shadow(radius: 3)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .id(liveFeedback.id) // For smooth transitions if message changes
                }
            }
            .padding(.horizontal)

            // Camera Switching Loading Indicator
             if viewModel.isSwitchingCamera {
                 VStack {
                     ProgressView()
                         .scaleEffect(1.5)
                         .padding(.bottom, 8)
                     Text("Switching Camera...")
                         .font(.caption)
                         .foregroundColor(.secondary)
                 }
                 .padding(20)
                 .background(Material.ultraThin)
                 .cornerRadius(10)
                 .shadow(radius: 5)
             }

        }
        .frame(height: geometry.size.width * (16/9)) // Match CameraPreviewView height
        .padding(.top)

        liveCameraControlButtons()
            .padding(.bottom, 5)
        
        // Summary Button for Live Mode
        if viewModel.currentMode == .liveCamera && viewModel.analysisCompletedForLive && !viewModel.isLiveSessionRunning {
            Button {
                viewModel.showLiveSummarySheet = true
            } label: {
                Label("View Feedback Summary", systemImage: "list.bullet.clipboard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 10) // Add some spacing
        }
    }
    
    @ViewBuilder
    private func liveCameraPermissionPlaceholderView() -> some View {
        VStack(spacing: 15) {
            Image(systemName: "camera.slash.fill")
                .resizable().scaledToFit().frame(height: 70)
                .foregroundColor(.orange)
            Text("Camera Access Needed")
                .font(.headline).foregroundColor(.primary)
            Text(viewModel.statusMessage.contains("Settings") ? viewModel.statusMessage : "Enable camera access in your device settings to use the live session.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            if !viewModel.statusMessage.contains("Settings") { // Don't show button if main status already directs to settings
                 Button("Check Permission") {
                     viewModel.checkCameraPermission()
                 }
                 .buttonStyle(.bordered)
                 .padding(.top)
            } else if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                Button("Open Settings") {
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250) // Match general player height
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }


    @ViewBuilder
    private func liveCameraControlButtons() -> some View {
        VStack(spacing: 12) {
            Button {
                if viewModel.isLiveSessionRunning {
                    viewModel.stopLiveAnalysis()
                } else {
                    viewModel.startLiveAnalysis()
                }
            } label: {
                if viewModel.isLiveSessionRunning {
                    Label("Stop Live Session", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                } else {
                    if viewModel.isProcessing && !viewModel.isLiveSessionRunning { // e.g. camera is starting
                         HStack { ProgressView().tint(colorScheme == .dark ? .white : .black); Text("Preparing...") }
                             .frame(maxWidth: .infinity)
                    } else {
                        Label("Start Live Squat Session", systemImage: "figure.mixed.cardio")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isLiveSessionRunning ? .red : .accentColor)
            .disabled((viewModel.isProcessing && !viewModel.isLiveSessionRunning) || !viewModel.isCameraPermissionGranted || viewModel.currentMode != .liveCamera)
            .padding(.horizontal)
            
            // Camera Toggle Button
            Button {
                viewModel.toggleCamera()
            } label: {
                Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera.fill")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLiveSessionRunning || !viewModel.isCameraPermissionGranted || viewModel.currentMode != .liveCamera)
            .padding(.horizontal)
        }
    }


    // MARK: - Common Views (Status, Feedback List)
    @ViewBuilder
    private func statusMessageView() -> some View {
        // (Your existing statusMessageView from VisionView.txt source: 182-183,
        //  but make it more generic or adapt based on mode)
        // Text should come from viewModel.statusMessage
        if !viewModel.statusMessage.isEmpty && (viewModel.isProcessing || viewModel.analysisCompleted || viewModel.isLiveSessionRunning || viewModel.currentMode == .liveCamera && !viewModel.isCameraPermissionGranted || viewModel.currentMode == .liveCamera && viewModel.isLiveSessionRunning == false) {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(viewModel.errorMessage != nil ? .red : .secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .transition(.opacity)
                .id("status_" + viewModel.statusMessage) // For transition animation
        }
    }
    
    // This view shows displayFeedbackItems, which is populated based on mode
    @ViewBuilder
    private func commonFeedbackDisplayView() -> some View {
        // --- Step 1: Compute your state variables ---
        // Use a small, immediately-executed closure to determine these values.
        let (itemsToDisplay, summaryTitle, currentItemCountForLog): ([FeedbackItem], String, Int) = {
            if viewModel.showLiveSummarySheet { // Sheet is specifically for the live summary
                let items = viewModel.liveSummaryFeedbackItems
                let title = "Live Session Squat Summary"
                let count = items.count
                // It's okay to keep prints here for debugging during development
                print("commonFeedbackDisplayView (Values Logic): Mode=LiveSheet, ItemsSource=liveSummaryFeedbackItems, Count=\(count)")
                return (items, title, count)
            } else if viewModel.currentMode == .videoUpload && viewModel.analysisCompleted {
                let items = viewModel.displayFeedbackItems
                let title = "Video Analysis Summary"
                let count = items.count
                print("commonFeedbackDisplayView (Values Logic): Mode=VideoUpload, ItemsSource=displayFeedbackItems, Count=\(count)")
                return (items, title, count)
            } else {
                let items: [FeedbackItem] = [] // Explicitly type if needed for clarity
                let title = "Summary"
                let count = 0
                print("commonFeedbackDisplayView (Values Logic): Mode=Fallback, Count=\(count)")
                return (items, title, count)
            }
        }() // The '()' executes the closure immediately

        // --- Step 2: Determine if the summary should be shown based on the computed items ---
        let shouldShowSummaryBasedOnItems = !itemsToDisplay.isEmpty
        // Optional: print the result of this check
        //print("commonFeedbackDisplayView (Values Logic): shouldShowSummaryBasedOnItems = \(shouldShowSummaryBasedOnItems), FinalItemCountForUI = \(itemsToDisplay.count)")

        // --- Step 3: Now, build your View structure using the computed values ---
        if shouldShowSummaryBasedOnItems {
            List {
//                // DEBUG Section: Render all items from the chosen source
//                Section(header: Text("Debug Info: Displaying \(itemsToDisplay.count) items for \(summaryTitle)")) {
//                    if itemsToDisplay.isEmpty { // Should not happen if shouldShowSummaryBasedOnItems is true
//                        Text("itemsToDisplay is unexpectedly empty here.")
//                    } else {
//                        ForEach(itemsToDisplay) { item in
//                            VStack(alignment: .leading) {
//                                Text("ID: \(item.id) | Type: \(item.type.rawValue)")
//                                Text(item.message).font(.caption)
//                            }
//                            .padding(.vertical, 1)
//                        }
//                    }
//                }

                // Your original Section logic (using itemsToDisplay and summaryTitle)
                Section { // Main content section
                    if itemsToDisplay.allSatisfy({ $0.type == .positive || $0.type == .detectionQuality }) {
                        if itemsToDisplay.count == 1 && itemsToDisplay.first?.type == .positive {
                            positiveFeedbackSummaryRow(items: itemsToDisplay)
                        } else {
                            ForEach(itemsToDisplay.sorted(by: feedbackSortOrder)) { item in
                                feedbackListRow(item: item)
                            }
                        }
                    } else {
                        // Constructive feedback items
                        let constructiveItems = itemsToDisplay.filter { $0.type != .positive && $0.type != .detectionQuality }
                        if !constructiveItems.isEmpty {
                             Section(header: Text("Areas for Improvement")) {
                                ForEach(constructiveItems.sorted(by: feedbackSortOrder)) { item in
                                    feedbackListRow(item: item)
                                }
                            }
                        }

                        // Positive feedback items
                        let positiveItems = itemsToDisplay.filter { $0.type == .positive }
                        if !positiveItems.isEmpty {
                            Section(header: Text("Good Points")) {
                                ForEach(positiveItems.sorted(by: feedbackSortOrder)) { item in
                                    feedbackListRow(item: item)
                                }
                            }
                        }
                         // Detection quality items
                        let detectionItems = itemsToDisplay.filter { $0.type == .detectionQuality }
                        if !detectionItems.isEmpty {
                             Section(header: Text("Detection Notes")) {
                                ForEach(detectionItems.sorted(by: feedbackSortOrder)) { item in
                                    feedbackListRow(item: item)
                                }
                            }
                        }
                    }
                } header: {
                    Text(summaryTitle) // Use the determined title
                        .font(.headline)
                        .padding(.top)
                }
            }
            .listStyle(.insetGrouped)
            .shrinkIfNeeded()
            .padding(.horizontal)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeInOut, value: itemsToDisplay)

        } else {
            // Fallback if no items to display for the determined context
            VStack {
                Text("\(summaryTitle) Not Available")
                    .font(.headline)
                Text("(No feedback items to display)")
                    .font(.subheadline)
                // Use the logged count variable here
                Text("Debug: itemsToDisplay.count was \(currentItemCountForLog) when deciding.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .padding()
        }
    }

    private func feedbackSortOrder(item1: FeedbackItem, item2: FeedbackItem) -> Bool {
        let priority: [FeedbackItem.FeedbackType: Int] = [
            .depth: 1, .kneeValgus: 2, .torsoAngle: 3, .ascentRate: 4, .heelLift: 5, .detectionQuality: 6, .liveInstruction: 7, .repComplete: 8, .positive: 99
        ]
        return (priority[item1.type] ?? 100) < (priority[item2.type] ?? 100)
    }

    @ViewBuilder
    private func feedbackListRow(item: FeedbackItem) -> some View {
        // NavigationLink will handle the presentation.
        // The destination is a wrapper that will manage fetching the image.
        NavigationLink(destination: FeedbackDetailWrapperView(item: item, viewModel: viewModel)) {
            // This is the content of your row (the "label" of the NavigationLink)
            HStack(spacing: 12) {
                feedbackIcon(for: item.type)
                    .font(.headline).foregroundColor(feedbackIconColor(for: item.type))
                    .frame(width: 25, alignment: .center)
                VStack(alignment: .leading) {
                    Text(item.type.rawValue).font(.callout.weight(.medium)).foregroundColor(.primary)
                    Text(item.message).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                // The chevron is usually provided by NavigationLink when in a List
            }
            .padding(.vertical, 6)
        }
        // .buttonStyle(.plain) // May not be needed or could conflict; NavigationLink handles tap
    }
    
    struct FeedbackDetailWrapperView: View {
        let item: FeedbackItem
        @ObservedObject var viewModel: VisionViewModel // Use ObservedObject as it's passed in

        @State private var frameImage: UIImage? = nil
        @State private var isLoadingImage: Bool = false

        var body: some View {
            FeedbackDetailSheet(
                item: item,
                frameImage: frameImage,
                isLoadingImage: isLoadingImage // Pass loading state
            )
            .onAppear {
                // Only load image if it's a video item with a timestamp and image hasn't been loaded
                if item.timestamp != nil && frameImage == nil {
                    loadImage()
                }
            }
        }

        private func loadImage() {
            // The item itself is passed to fetchFrameImageForItem
            guard item.timestamp != nil else {
                print("WrapperView: Item \(item.type.rawValue) has no timestamp. No image to load.")
                // isLoadingImage should ideally be set to false here if we decide not to load
                // However, the primary guard in fetchFrameImageForItem on the ViewModel handles this.
                // For clarity, ensure isLoadingImage is false if we bail early.
                Task { await MainActor.run { self.isLoadingImage = false } }
                return
            }

            self.isLoadingImage = true // Set loading true before the async task
            Task {
                // Corrected call to the ViewModel's method
                let image = await viewModel.fetchFrameImageForItem(item)
                await MainActor.run {
                    self.frameImage = image
                    self.isLoadingImage = false
                }
            }
        }
    }

    // positiveFeedbackSummaryRow modified to take items
    @ViewBuilder
    private func positiveFeedbackSummaryRow(items: [FeedbackItem]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline).foregroundColor(.green)
                .frame(width: 25, alignment: .center)
             VStack(alignment: .leading) {
                 Text("Good Form").font(.callout.weight(.medium)).foregroundColor(.primary)
                 Text(items.first(where: {$0.type == .positive})?.message ?? "No major issues detected.")
                     .font(.caption).foregroundColor(.secondary).lineLimit(1)
             }
        }
        .padding(.vertical, 6)
    }

    private func feedbackIcon(for type: FeedbackItem.FeedbackType) -> Image {
        switch type {
        case .depth: return Image(systemName: "arrow.down.to.line.compact")
        case .kneeValgus: return Image(systemName: "arrow.right.to.line.compact.and.arrow.left.to.line.compact")
        case .torsoAngle: return Image(systemName: "figure.walk") // Consider body.outline
        case .heelLift: return Image(systemName: "shoe.heels") // Consider arrow.up.to.line.compact or similar for lift
        case .ascentRate: return Image(systemName: "arrow.up.and.person.rectangle.portrait")
        case .detectionQuality: return Image(systemName: "exclamationmark.triangle.fill")
        case .positive: return Image(systemName: "checkmark.seal.fill")
        case .liveInstruction: return Image(systemName: "info.circle.fill")
        case .repComplete: return Image(systemName: "figure.roll.runningpace") // Or "flag.checkered"
        }
    }

     private func feedbackIconColor(for type: FeedbackItem.FeedbackType) -> Color {
         switch type {
         case .depth, .kneeValgus, .torsoAngle, .heelLift, .ascentRate: return .orange
         case .detectionQuality: return .red
         case .positive: return .green
         case .liveInstruction: return .blue
         case .repComplete: return .purple
         }
     }
     
     private func feedbackTextColor(for type: FeedbackItem.FeedbackType) -> Color {
         switch type {
         case .depth, .kneeValgus, .torsoAngle, .heelLift, .ascentRate: return .orange
         case .detectionQuality: return .red
         case .positive: return .green
         case .liveInstruction, .repComplete: return colorScheme == .dark ? .white : .black // Or specific colors
         }
     }
}


// MARK: - Camera Preview and Overlay Views
struct CameraPreviewView: UIViewRepresentable {
    var captureSession: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewLayerView()
        view.videoPreviewLayer.session = captureSession
        view.videoPreviewLayer.videoGravity = .resizeAspectFill // Or .resizeAspect
        // Handle initial orientation if needed, though connection setting is primary
        // view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The session is set in makeUIView. If session could change, update here.
        // The PreviewLayerView handles its own layoutSubviews for layer frame.
    }
    
    // Custom UIView subclass to manage the preview layer's frame correctly
    class PreviewLayerView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = self.bounds // Ensure layer frame updates with view bounds
        }
    }
}

struct PoseOverlayView: View {
    let posePoints: [CGPoint?]?
    let dotRadius: CGFloat = 5
    let lineWidth: CGFloat = 2

    // Define connections between joints for drawing lines
    private let bodyConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip), (.leftShoulder, .rightShoulder), // Torso
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),       // Left Leg
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)    // Right Leg
    ]
    
    // Map VNHumanBodyPoseObservation.JointName to the indices used in PoseAnalyzer
    private func pointForJoint(_ jointName: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let points = posePoints else { return nil }
        let idx: Int?
        switch jointName {
            case .root: idx = 0 // Example, map all needed joints
            case .leftHip: idx = 1
            case .rightHip: idx = 2
            case .leftKnee: idx = 3
            case .rightKnee: idx = 4
            case .leftAnkle: idx = 5
            case .rightAnkle: idx = 6
            case .leftShoulder: idx = 7
            case .rightShoulder: idx = 8
            default: idx = nil
        }
        guard let jointIdx = idx, points.indices.contains(jointIdx) else { return nil }
        return points[jointIdx]
    }


    var body: some View {
        Canvas { context, size in
            guard let points = posePoints else { return }

            // Draw lines first
            for connection in bodyConnections {
                guard let p1Raw = pointForJoint(connection.0), let p2Raw = pointForJoint(connection.1) else {
                    continue
                }
                // Vision coordinates are normalized (0,0 bottom-left). Convert to SwiftUI (0,0 top-left).
                let p1 = CGPoint(x: p1Raw.x * size.width, y: (1 - p1Raw.y) * size.height)
                let p2 = CGPoint(x: p2Raw.x * size.width, y: (1 - p2Raw.y) * size.height)

                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(.green), lineWidth: lineWidth)
            }

            // Draw dots on top
            for pointData in points.compactMap({ $0 }) {
                let visionPoint = CGPoint(x: pointData.x * size.width, y: (1 - pointData.y) * size.height)
                let rect = CGRect(x: visionPoint.x - dotRadius, y: visionPoint.y - dotRadius,
                                  width: 2 * dotRadius, height: 2 * dotRadius)
                context.fill(Path(ellipseIn: rect), with: .color(.red))
            }
        }
    }
}

// MARK: - Detail Sheet View (New/Modified)
struct FeedbackDetailSheet: View {
    @StateObject private var viewModel = VisionViewModel()

    let item: FeedbackItem
    let frameImage: UIImage?
    let isLoadingImage: Bool // New property to indicate image loading status

    @Environment(\.dismiss) var dismiss

    var body: some View {
        // The NavigationView here is for THIS view's own title bar and Done button.
        // It does NOT conflict with the NavigationView of the summary sheet.
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Frame Image Section
                    if item.timestamp != nil && viewModel.currentMode == .videoUpload { // Condition to show image section
                        VStack(alignment: .leading) {
                            Text("Relevant Frame (Video Analysis)")
                                .font(.title3.weight(.semibold))
                            if isLoadingImage { // Check the passed-in loading state
                                ProgressView("Loading Frame...")
                                    .frame(maxWidth: .infinity).frame(height: 200)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if let image = frameImage {
                                Image(uiImage: image)
                                    .resizable().scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                // Case for when not loading, but no image (e.g., fetch failed or not applicable)
                                Text("Frame image not available.")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(height: 100) // Adjust size as needed
                                    .background(Color(.secondarySystemBackground).opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.vertical, 50) // Give it some space
                            }
                        }
                    } else if item.timestamp != nil && viewModel.currentMode == .liveCamera {
                        // If it's live feedback that had a timestamp but we don't show frame images for it.
                        // This section can be omitted or show a message.
                        // For now, we only show images if it's video upload mode.
                    }


                    Divider()

                    // Feedback Details Section (remains mostly the same)
                    VStack(alignment: .leading, spacing: 15) {
                         Text(item.type.rawValue)
                             .font(.title2.weight(.semibold))
                             .foregroundColor(feedbackIconColor(for: item.type, defaultColor: .primary))

                         Text(item.message)
                             .font(.headline).foregroundColor(.primary)

                         if let explanation = item.detailedExplanation, !explanation.isEmpty {
                             ExpandableSection(title: "What this means") { Text(explanation).font(.body) }
                         }
                         if let causes = item.potentialCauses, !causes.isEmpty, causes != "N/A" {
                            ExpandableSection(title: "Potential Causes") { Text(causes).font(.body) }
                         }
                         if let suggestions = item.correctiveSuggestions, !suggestions.isEmpty, suggestions != "N/A" {
                             ExpandableSection(title: "Corrective Suggestions") { Text(suggestions).font(.body) }
                         }
                    }
                }
                .padding()
            }
//            .navigationTitle("Feedback Detail")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") { dismiss() }
//                }
//            }
        }
        // IMPORTANT: Prevent this NavigationView from interfering with the outer one for swipe gestures.
        // This is only an issue if this sheet *itself* were presented with .sheet().
        // When pushed, it's usually fine. Test swipe-back behavior.
        // .navigationViewStyle(.stack) // Might be useful if you saw oddities, but often not needed.
    }

    // Helper from VisionView, ensure it's accessible
    private func feedbackIconColor(for type: FeedbackItem.FeedbackType, defaultColor: Color) -> Color {
         switch type {
         case .depth, .kneeValgus, .torsoAngle, .heelLift, .ascentRate: return .orange // [cite: 266]
         case .detectionQuality: return .red // [cite: 266]
         case .positive: return .green // [cite: 266]
         case .liveInstruction: return .blue // [cite: 266]
         case .repComplete: return .purple // [cite: 266]
         default: return defaultColor
         }
     }
}

struct ExpandableSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool = true // Start expanded for better UX

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title).font(.title3.weight(.medium)) // Adjusted font
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.top, 5)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top))) // Nicer transition
            }
        }
    }
}

struct ShrinkIfNeeded: ViewModifier {
    // (Your existing ShrinkIfNeeded and HeightPreferenceKey from VisionView.txt source: 229-232)
    @State private var contentHeight: CGFloat = .zero
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                 if abs(contentHeight - height) > 1 {
                     self.contentHeight = height
                 }
            }
            .frame(height: contentHeight > 10 ? contentHeight : nil)
    }
}
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
extension View {
    func shrinkIfNeeded() -> some View {
        self.modifier(ShrinkIfNeeded())
    }
}


// MARK: - Preview Provider
struct VisionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VisionView()
        }
    }
}
