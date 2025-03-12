import SwiftUI

struct WorkoutTimerView: View {
    let startTime: Date
    @State private var timeElapsed: TimeInterval = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
            Text(formattedTime)
                .monospacedDigit()
        }
        .onReceive(timer) { _ in
            timeElapsed = Date().timeIntervalSince(startTime)
        }
    }
    
    private var formattedTime: String {
        let hours = Int(timeElapsed) / 3600
        let minutes = Int(timeElapsed) / 60 % 60
        let seconds = Int(timeElapsed) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
} 