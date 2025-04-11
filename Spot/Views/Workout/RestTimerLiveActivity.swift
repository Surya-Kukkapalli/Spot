import SwiftUI
import WidgetKit
import ActivityKit

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var remainingTime: TimeInterval
    }
    
    var exerciseName: String
    var setNumber: Int
}

@available(iOS 16.1, *)
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Live activity view (Dynamic Island)
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("\(context.attributes.exerciseName) - Set \(context.attributes.setNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.exerciseName)
                    } icon: {
                        Image(systemName: "timer.circle.fill")
                    }
                    .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Set \(context.attributes.setNumber)")
                        .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(.title, design: .rounded).monospacedDigit())
                        .foregroundColor(.blue)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar
                    ProgressView(value: context.state.remainingTime, total: 90)
                        .tint(.blue)
                }
            } compactLeading: {
                Image(systemName: "timer.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.blue)
            } minimal: {
                Image(systemName: "timer.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
} 
