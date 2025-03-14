import SwiftUI
import Charts

struct WorkoutChartView: View {
    let data: [WorkoutDataPoint]
    @Binding var selectedMetric: ProfileViewModel.WorkoutMetric
    
    struct WorkoutDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let duration: Double
        let volume: Double
        let reps: Int
    }
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Value", getValue(point))
                )
                .foregroundStyle(Color.blue)
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
    }
    
    private func getValue(_ point: WorkoutDataPoint) -> Double {
        switch selectedMetric {
        case .duration:
            return point.duration
        case .volume:
            return point.volume
        case .reps:
            return Double(point.reps)
        }
    }
} 