import SwiftUI
import Charts

struct WorkoutChartView: View {
    let data: [(date: Date, value: Double)]
    @Binding var selectedMetric: ProfileViewModel.WorkoutMetric
    @State private var timeRange: TimeRange = .threeMonths
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            }
        }
        
        var groupingDays: Int {
            switch self {
            case .week: return 1 // Daily
            case .month: return 7 // Weekly
            case .threeMonths: return 14 // Bi-weekly
            case .sixMonths: return 30 // Monthly
            case .year: return 30 // Monthly
            }
        }
    }
    
    var filteredAndGroupedData: [(date: Date, value: Double)] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        let filteredData = data.filter { $0.date >= cutoffDate }
        
        // Group data by time periods
        var groupedData: [Date: [Double]] = [:]
        let calendar = Calendar.current
        
        for item in filteredData {
            // Get the start of the period for grouping
            let periodStart = calendar.date(
                byAdding: .day,
                value: -(calendar.component(.day, from: item.date) % timeRange.groupingDays),
                to: item.date
            ) ?? item.date
            
            if groupedData[periodStart] == nil {
                groupedData[periodStart] = []
            }
            groupedData[periodStart]?.append(item.value)
        }
        
        // Convert grouped data to array and sort by date
        return groupedData.map { (date, values) in
            (date: date, value: values.reduce(0, +))
        }.sorted { $0.date < $1.date }
    }
    
    var yAxisLabel: String {
        switch selectedMetric {
        case .duration: return "Minutes"
        case .volume: return "Volume (lbs)"
        case .reps: return "Total Reps"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Time Range:")
                    .foregroundColor(.secondary)
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if filteredAndGroupedData.isEmpty {
                Text("No workout data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(filteredAndGroupedData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value(yAxisLabel, item.value)
                        )
                        .foregroundStyle(.blue)
                        
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value(yAxisLabel, item.value)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        
                        PointMark(
                            x: .value("Date", item.date),
                            y: .value(yAxisLabel, item.value)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatYAxisValue(doubleValue))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: getXAxisStride())) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatDate(date))
                                    .rotationEffect(.degrees(-45))
                                    .offset(y: 10)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getXAxisStride() -> Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .month: return .weekOfMonth
        case .threeMonths, .sixMonths: return .month
        case .year: return .month
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            formatter.dateFormat = "MMM d"
        case .threeMonths, .sixMonths, .year:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
    
    private func formatYAxisValue(_ value: Double) -> String {
        switch selectedMetric {
        case .duration:
            return "\(Int(value))m"
        case .volume:
            return "\(Int(value))lbs"
        case .reps:
            return "\(Int(value))"
        }
    }
} 
