import SwiftUI
import PhotosUI
import AVKit

struct VisionView: View {
    @StateObject private var viewModel = VisionViewModel()

    var body: some View {
        // Use GeometryReader to allow content to define ScrollView height naturally
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {

                    // --- Video Display Area ---
                    videoPlayerView()
                        .padding(.top)

                    // --- Control Buttons Area ---
                    controlButtonsView()
                        .padding(.bottom, 5)

                    // --- Status Message ---
                    statusMessageView()

                    // --- Form Feedback Section ---
                    feedbackListView() // Let this define its own height

                    Spacer() // Pushes content towards the top if ScrollView content is short
                }
                .padding(.bottom)
                // Ensure the VStack takes at least the height of the screen within ScrollView
                .frame(minHeight: geometry.size.height)
            }
        }
        .navigationTitle("Form Analyzer")
        .background(Color(.systemGroupedBackground).ignoresSafeArea(.all, edges: .bottom))
        .sheet(item: $viewModel.selectedFeedbackItem) { item in
            // Use .sheet(item: ...) which provides the item to the closure
             FeedbackDetailSheet(item: item, frameImage: viewModel.selectedFrameImage)
         }
        .onDisappear {
             viewModel.cleanupResources()
        }
        .alert("Analysis Error", isPresented: $viewModel.showErrorAlert, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Subviews (Video Player, Placeholder, Controls, Status - Keep as before)
     @ViewBuilder
    private func videoPlayerView() -> some View {
        Group {
            if let player = viewModel.videoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    // Removed autoplay/pause for simplicity, can be added back
            } else {
                placeholderView()
            }
        }
    }

     @ViewBuilder
    private func placeholderView() -> some View {
        VStack(spacing: 15) {
            Image(systemName: "figure.squat")
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .foregroundColor(.accentColor.opacity(0.8))
            Text("Select Squat Video")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Select a video of your squat for form analysis and feedback.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }


    @ViewBuilder
    private func controlButtonsView() -> some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $viewModel.selectedVideoItem, matching: .videos) {
                 Label("Select Video", systemImage: "video.badge.plus")
                     .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .disabled(viewModel.isProcessing)
            .padding(.horizontal)

            Button {
                viewModel.startVideoAnalysis()
            } label: {
                if viewModel.isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.primary)
                        Text("Analyzing...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                } else {
                    Label("Analyze Squat Form", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.videoURL == nil || viewModel.isProcessing)
            .padding(.horizontal)
             .animation(.easeInOut(duration: 0.2), value: viewModel.isProcessing)
        }
    }

    @ViewBuilder
    private func statusMessageView() -> some View {
        if viewModel.isProcessing || viewModel.analysisCompleted {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(viewModel.statusMessage.contains("Error") ? .red : .secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .transition(.opacity)
                 .id("status_" + viewModel.statusMessage)
        }
    }


    // MARK: - Feedback List View (Modified)
    @ViewBuilder
    private func feedbackListView() -> some View {
        // Show only if analysis complete AND no critical error message shown in status
        if viewModel.analysisCompleted && !viewModel.statusMessage.contains("Analysis failed") && !viewModel.statusMessage.contains("no feedback generated") {
             List {
                 Section {
                     // Handle "no issues detected" case specifically
                     if viewModel.feedbackItems.allSatisfy({ $0.type == .positive || $0.type == .detectionQuality }) && !viewModel.feedbackItems.isEmpty {
                         positiveFeedbackSummaryRow() // Show summary row
                     } else {
                         // Display actual feedback items (non-positive ones first)
                         ForEach(viewModel.feedbackItems.filter { $0.type != .positive }.sorted(by: feedbackSortOrder)) { item in
                             feedbackListRow(item: item) // Use the simplified list row
                         }
                     }
                 } header: {
                     Text("Analysis Summary") // Changed header
                         .font(.headline)
                 }
             }
             .listStyle(.insetGrouped)
             // REMOVED fixed height - let list grow naturally within ScrollView
             .shrinkIfNeeded() // Custom modifier to prevent list from taking excessive empty space
             .padding(.horizontal)
             .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
             .transition(.opacity.combined(with: .scale(scale: 0.95)))
             .animation(.easeInOut, value: viewModel.feedbackItems)
        }
    }

    // Sort order for feedback (reuse from previous version)
    private func feedbackSortOrder(item1: FeedbackItem, item2: FeedbackItem) -> Bool {
        let priority: [FeedbackItem.FeedbackType: Int] = [
            .depth: 1, .kneeValgus: 2, .torsoAngle: 3, .ascentRate: 4, .heelLift: 5, .detectionQuality: 6, .positive: 7
        ]
        return (priority[item1.type] ?? 99) < (priority[item2.type] ?? 99)
    }


    // Simplified Row for the main list
    @ViewBuilder
    private func feedbackListRow(item: FeedbackItem) -> some View {
         // Make the entire row tappable to show details
         Button {
             viewModel.selectFeedbackItemForDetail(item)
         } label: {
             HStack(spacing: 12) {
                 feedbackIcon(for: item.type)
                     .font(.headline) // Make icon slightly larger
                     .foregroundColor(feedbackIconColor(for: item.type))
                     .frame(width: 25, alignment: .center) // Align icon

                 VStack(alignment: .leading) {
                     Text(item.type.rawValue) // Show the type as title (e.g., "Knee Position")
                         .font(.callout.weight(.medium)) // Medium weight title
                         .foregroundColor(.primary)
                     Text(item.message) // Show the concise message below
                         .font(.caption) // Smaller caption for message
                         .foregroundColor(.secondary)
                         .lineLimit(1) // Keep message short in list
                 }

                 Spacer()

                 // Show chevron only if details can be shown (has timestamp or actionable info)
                  if item.timestamp != nil || item.detailedExplanation != nil {
                      Image(systemName: "chevron.right")
                          .font(.footnote.weight(.semibold))
                          .foregroundColor(.secondary.opacity(0.7))
                  }
             }
             .padding(.vertical, 6) // Adjust padding
         }
         .buttonStyle(.plain) // Use plain button style for list rows
     }


    // Row for positive feedback summary
    @ViewBuilder
    private func positiveFeedbackSummaryRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(.green)
                .frame(width: 25, alignment: .center)
             VStack(alignment: .leading) {
                 Text("Good Form")
                     .font(.callout.weight(.medium))
                     .foregroundColor(.primary)
                 Text(viewModel.feedbackItems.first(where: {$0.type == .positive})?.message ?? "No major issues detected.")
                     .font(.caption)
                     .foregroundColor(.secondary)
                     .lineLimit(1)
             }
        }
        .padding(.vertical, 6)
    }


    // Helper to get icon/color (reuse from previous version)
    private func feedbackIcon(for type: FeedbackItem.FeedbackType) -> Image {
        switch type {
        case .depth: return Image(systemName: "arrow.down.to.line.compact")
        case .kneeValgus: return Image(systemName: "arrow.right.to.line.compact.and.arrow.left.to.line.compact")
        case .torsoAngle: return Image(systemName: "figure.walk")
        case .heelLift: return Image(systemName: "shoe.heels")
        case .ascentRate: return Image(systemName: "arrow.up.and.person.rectangle.portrait")
        case .detectionQuality: return Image(systemName: "exclamationmark.triangle")
        case .positive: return Image(systemName: "checkmark.seal.fill")
        }
    }

     private func feedbackIconColor(for type: FeedbackItem.FeedbackType) -> Color {
         switch type {
         case .depth, .kneeValgus, .torsoAngle, .heelLift, .ascentRate: return .orange
         case .detectionQuality: return .red
         case .positive: return .green
         }
     }


    // MARK: - Helper Functions (Removed calculateListHeight)
}

// MARK: - Detail Sheet View (New/Modified)

struct FeedbackDetailSheet: View {
    let item: FeedbackItem // Passed in when sheet is presented
    let frameImage: UIImage? // Passed in separately

    var body: some View {
        NavigationView { // Embed in NavigationView for title and potential toolbar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Frame Image Section
                    if item.timestamp != nil { // Only show image section if timestamp exists
                        VStack(alignment: .leading) {
                            Text("Relevant Frame")
                                .font(.title3.weight(.semibold))
                            if let image = frameImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                // Provide a loading state or placeholder
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200) // Give it some space
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    Divider()

                    // Feedback Details Section
                    VStack(alignment: .leading, spacing: 15) {
                         Text(item.type.rawValue) // E.g., "Knee Position"
                             .font(.title2.weight(.semibold))
                             .foregroundColor(feedbackIconColor(for: item.type)) // Color the title

                         // Original Message (more prominent)
                         Text(item.message)
                             .font(.headline)
                             .foregroundColor(.primary)

                         // Detailed Explanation
                         if let explanation = item.detailedExplanation {
                             ExpandableSection(title: "What this means") {
                                 Text(explanation)
                                     .font(.body)
                             }
                         }

                         // Potential Causes
                         if let causes = item.potentialCauses {
                             ExpandableSection(title: "Potential Causes") {
                                 Text(causes)
                                     .font(.body)
                            }
                         }

                         // Corrective Suggestions
                         if let suggestions = item.correctiveSuggestions {
                             ExpandableSection(title: "Corrective Suggestions") {
                                 Text(suggestions)
                                     .font(.body)
                             }
                         }
                    }
                }
                .padding() // Add padding around the content
            }
            .navigationTitle("Feedback Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss the sheet - handled by system via @Environment(\.dismiss) or sheet binding
                    }
                }
            }
        }
        // Apply presentation detents if needed
        // .presentationDetents([.medium, .large])
    }

     // Replicate helper here or pass color via item
     private func feedbackIconColor(for type: FeedbackItem.FeedbackType) -> Color {
         switch type {
         case .depth, .kneeValgus, .torsoAngle, .heelLift, .ascentRate: return .orange
         case .detectionQuality: return .red
         case .positive: return .green
         }
     }
}

// Simple Expandable Section View
struct ExpandableSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool = false // Start collapsed

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.title3) // Smaller title for sections
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
                    .foregroundColor(.secondary) // Default text color for content
                     .transition(.opacity.combined(with: .slide)) // Add transition
            }
        }
    }
}


// Custom ViewModifier to prevent List from taking up all available space
struct ShrinkIfNeeded: ViewModifier {
    @State private var contentHeight: CGFloat = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                 // Only update if height is substantially different to avoid loops
                 if abs(contentHeight - height) > 1 {
                     self.contentHeight = height
                 }
            }
            .frame(height: contentHeight > 10 ? contentHeight : nil) // Apply height only if content exists
    }
}

// PreferenceKey to read content height
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
