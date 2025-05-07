import SwiftUI
import Charts
import FirebaseAuth
import FirebaseFirestore

class ExerciseDetailsViewModel: ObservableObject {
    @Published var selectedTimeRange: TimeRange = .threeMonths {
        didSet {
            Task {
                await loadData()
            }
        }
    }
    @Published var selectedMetric: ExerciseMetric = .heaviestWeight {
        didSet {
            Task {
                await loadData()
            }
        }
    }
    @Published var exerciseData: [(date: Date, value: Double)] = []
    @Published var personalRecords: [String: PersonalRecord] = [:]
    @Published var isLoading = true
    @Published var error: String?
    @Published var exerciseDetails: ExerciseTemplate?
    
    private let exercise: ExerciseTemplate
    private let prService = PersonalRecordService()
    private let db = Firestore.firestore()
    
    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        Task {
            await loadExerciseDetails()
            await loadData()
        }
    }
    
    @MainActor
    private func loadExerciseDetails() async {
        do {
            if let details = try await ExerciseService.shared.fetchExerciseDetails(name: exercise.name) {
                print("DEBUG: Loaded exercise details for \(details.name)")
                print("DEBUG: - Instructions count: \(details.instructions.count)")
                print("DEBUG: - GifUrl: \(details.gifUrl)")
                self.exerciseDetails = details
            }
        } catch {
            print("DEBUG: Error loading exercise details: \(error)")
        }
    }
    
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
    }
    
    enum ExerciseMetric: String, CaseIterable {
        case heaviestWeight = "Heaviest Weight"
        case oneRepMax = "One Rep Max"
        case bestSetVolume = "Best Set Volume"
        case sessionVolume = "Session Volume"
        case totalReps = "Total Reps"
        
        var yAxisLabel: String {
            switch self {
            case .heaviestWeight, .oneRepMax:
                return "Weight (lbs)"
            case .bestSetVolume, .sessionVolume:
                return "Volume (lbs)"
            case .totalReps:
                return "Reps"
            }
        }
        
        func getValue(from pr: PersonalRecord) -> Double {
            switch self {
            case .heaviestWeight:
                return pr.weight
            case .oneRepMax:
                return pr.oneRepMax
            case .bestSetVolume:
                return pr.weight * Double(pr.reps)
            case .sessionVolume:
                return pr.weight * Double(pr.reps) * 1.5 // Simulated session volume
            case .totalReps:
                return Double(pr.reps)
            }
        }
    }
    
    @MainActor
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                error = "User not logged in"
                isLoading = false
                return
            }
            
            print("DEBUG: Loading data for exercise: \(exercise.name)")
            
            // Load personal records
            if let pr = try await prService.getPR(userId: userId, exerciseName: exercise.name) {
                personalRecords[exercise.name] = pr
                print("DEBUG: Found personal record: \(pr)")
            } else {
                print("DEBUG: No personal record found")
            }
            
            // Fetch workout history for this exercise
            print("DEBUG: Fetching workout history...")
            let workouts = try await db.collection("workouts")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            print("DEBUG: Found \(workouts.documents.count) total workout documents")
            
            // Process workout data
            var data: [(date: Date, value: Double)] = []
            
            for document in workouts.documents {
                print("DEBUG: Processing workout document: \(document.documentID)")
                let workoutData = document.data()
                
                // Get workout date first
                guard let timestamp = workoutData["createdAt"] as? Timestamp else {
                    print("DEBUG: No timestamp found for workout")
                    continue
                }
                let workoutDate = timestamp.dateValue()
                print("DEBUG: Workout date: \(workoutDate)")
                
                // Check if the document has exercises array
                guard let exercises = workoutData["exercises"] as? [[String: Any]] else {
                    print("DEBUG: No exercises array found in document")
                    continue
                }
                
                // Find matching exercise
                if let exerciseData = exercises.first(where: { exercise -> Bool in
                    guard let exerciseName = exercise["name"] as? String else { return false }
                    return exerciseName.lowercased() == self.exercise.name.lowercased()
                }) {
                    print("DEBUG: Found matching exercise: \(exerciseData)")
                    
                    // Extract sets
                    guard let sets = exerciseData["sets"] as? [[String: Any]] else {
                        print("DEBUG: No sets found for exercise")
                        continue
                    }
                    
                    // Only include completed sets
                    let completedSets = sets.filter { set in
                        guard let isCompleted = set["isCompleted"] as? Bool else { return false }
                        return isCompleted
                    }
                    
                    if completedSets.isEmpty {
                        print("DEBUG: No completed sets found")
                        continue
                    }
                    
                    // Calculate metric value
                    let value: Double
                    switch selectedMetric {
                    case .heaviestWeight:
                        value = completedSets.compactMap { set -> Double? in
                            guard let weight = set["weight"] as? Double else { return nil }
                            return weight
                        }.max() ?? 0
                    case .oneRepMax:
                        let maxOneRepMax = completedSets.compactMap { set -> Double? in
                            guard let weight = set["weight"] as? Double,
                                  let reps = set["reps"] as? Int
                            else { return nil }
                            return weight * (1 + Double(reps) / 30) // Brzycki formula
                        }.max() ?? 0
                        value = maxOneRepMax
                    case .bestSetVolume:
                        value = completedSets.compactMap { set -> Double? in
                            guard let weight = set["weight"] as? Double,
                                  let reps = set["reps"] as? Int
                            else { return nil }
                            return weight * Double(reps)
                        }.max() ?? 0
                    case .sessionVolume:
                        value = completedSets.reduce(0) { total, set in
                            guard let weight = set["weight"] as? Double,
                                  let reps = set["reps"] as? Int
                            else { return total }
                            return total + weight * Double(reps)
                        }
                    case .totalReps:
                        value = Double(completedSets.compactMap { $0["reps"] as? Int }.reduce(0, +))
                    }
                    
                    print("DEBUG: Adding data point - Date: \(workoutDate), Value: \(value)")
                    data.append((date: workoutDate, value: value))
                }
            }
            
            // Filter data based on selected time range
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
            exerciseData = data.filter { $0.date >= cutoffDate }
                .sorted { $0.date < $1.date }
            
            print("DEBUG: Final data points: \(exerciseData.count)")
            
        } catch {
            print("DEBUG: Error loading data: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func generateSampleData() -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var data: [(date: Date, value: Double)] = []
        let today = Date()
        
        // Generate sample data based on selected metric
        for i in 0..<selectedTimeRange.days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let value: Double
                switch selectedMetric {
                case .heaviestWeight:
                    value = Double.random(in: 100...300)
                case .oneRepMax:
                    value = Double.random(in: 150...400)
                case .bestSetVolume:
                    value = Double.random(in: 1000...3000)
                case .sessionVolume:
                    value = Double.random(in: 3000...10000)
                case .totalReps:
                    value = Double.random(in: 10...50)
                }
                data.append((date: date, value: value))
            }
        }
        
        return data.sorted { $0.date < $1.date }
    }
}

struct ExerciseDetailsView: View {
    let exercise: ExerciseTemplate
    @StateObject private var viewModel: ExerciseDetailsViewModel
    @State private var selectedTab = 0
    @State private var isLoading = true
    
    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        _viewModel = StateObject(wrappedValue: ExerciseDetailsViewModel(exercise: exercise))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TabBar(selectedTab: $selectedTab)
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding(.top, 100)
                        Text("Loading exercise details...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else {
                    switch selectedTab {
                    case 0:
                        SummaryTab(exercise: exercise, viewModel: viewModel)
                    case 1:
                        HistoryTab(viewModel: viewModel)
                    case 2:
                        HowToTab(exercise: exercise, viewModel: viewModel)
                    case 3:
                        LeaderboardTab(exercise: exercise)
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Simulate loading delay for smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Tab Bar
private struct TabBar: View {
    @Binding var selectedTab: Int
    private let tabs = ["Summary", "History", "How to", "Leaderboard"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    VStack {
                        Text(tabs[index])
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .onTapGesture {
                        withAnimation {
                            selectedTab = index
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Summary Tab
private struct SummaryTab: View {
    let exercise: ExerciseTemplate
    @ObservedObject var viewModel: ExerciseDetailsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Exercise GIF
            if let details = viewModel.exerciseDetails {
                AsyncImage(url: URL(string: details.gifUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
            
            // Exercise Info
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name.capitalized)
                    .font(.title2)
                    .bold()
                
                Text("Primary: \(exercise.target.capitalized)")
                    .font(.subheadline)
                
                if !exercise.secondaryMuscles.isEmpty {
                    Text("Secondary: \(exercise.secondaryMuscles.map { $0.capitalized }.joined(separator: ", "))")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            
            // Chart Section
            VStack(alignment: .leading, spacing: 8) {
                // Time range picker
                HStack {
                    Text("Time Range:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $viewModel.selectedTimeRange) {
                        ForEach(ExerciseDetailsViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                
                // Metric selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExerciseDetailsViewModel.ExerciseMetric.allCases, id: \.self) { metric in
                            Button(action: {
                                viewModel.selectedMetric = metric
                            }) {
                                Text(metric.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(viewModel.selectedMetric == metric ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(viewModel.selectedMetric == metric ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Chart
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let error = viewModel.error {
                    Text("Error: \(error)")
                        .frame(height: 200)
                        .foregroundColor(.red)
                } else if viewModel.exerciseData.isEmpty {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay(
                            Text("No data available")
                                .foregroundColor(.secondary)
                        )
                } else {
                    Chart {
                        ForEach(viewModel.exerciseData, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value(viewModel.selectedMetric.yAxisLabel, item.value)
                            )
                            .foregroundStyle(.blue)
                            
                            AreaMark(
                                x: .value("Date", item.date),
                                y: .value(viewModel.selectedMetric.yAxisLabel, item.value)
                            )
                            .foregroundStyle(.blue.opacity(0.1))
                        }
                    }
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
                    .frame(height: 200)
                    .padding()
                }
            }
            
            // Personal Records Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Personal Records")
                    .font(.title3)
                    .bold()
                    .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = viewModel.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if let pr = viewModel.personalRecords[exercise.name] {
                    VStack(spacing: 16) {
                        PersonalRecordRow(
                            title: "Heaviest Weight",
                            value: "\(Int(pr.weight))lbs"
                        )
                        
                        PersonalRecordRow(
                            title: "Best 1RM",
                            value: "\(Int(pr.oneRepMax))lbs"
                        )
                        
                        PersonalRecordRow(
                            title: "Best Set Volume",
                            value: "\(Int(pr.weight))lbs × \(pr.reps)"
                        )
                        
                        PersonalRecordRow(
                            title: "Best Session Volume",
                            value: "\(Int(pr.weight * Double(pr.reps)))lbs"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Text("No personal records yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
            // Strength Level Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Strength Level")
                    .font(.title3)
                    .bold()
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "person.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Add your sex, age and weight so that we can show you your strength level - Coming Soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private func getXAxisStride() -> Calendar.Component {
        switch viewModel.selectedTimeRange {
        case .week: return .day
        case .month: return .weekOfMonth
        case .threeMonths, .sixMonths: return .month
        case .year: return .month
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch viewModel.selectedTimeRange {
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
        switch viewModel.selectedMetric {
        case .heaviestWeight, .oneRepMax:
            return "\(Int(value))lbs"
        case .bestSetVolume, .sessionVolume:
            return "\(Int(value))lbs"
        case .totalReps:
            return "\(Int(value))"
        }
    }
}

// MARK: - History Tab
private struct HistoryTab: View {
    @ObservedObject var viewModel: ExerciseDetailsViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
            } else if viewModel.exerciseData.isEmpty {
                Text("No workout history available")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.exerciseData.sorted(by: { $0.date > $1.date }), id: \.date) { data in
                            let _ = print("DEBUG: Displaying workout from \(formatDate(data.date)) with value: \(data.value)")
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formatDate(data.date))
                                    .font(.headline)
                                
                                HStack {
                                    Text("\(viewModel.selectedMetric.rawValue):")
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", data.value))
                                        .bold()
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            print("DEBUG: HistoryTab appeared with \(viewModel.exerciseData.count) data points")
            print("DEBUG: Selected metric: \(viewModel.selectedMetric.rawValue)")
            print("DEBUG: Selected time range: \(viewModel.selectedTimeRange.rawValue)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - How To Tab
private struct HowToTab: View {
    let exercise: ExerciseTemplate
    @ObservedObject var viewModel: ExerciseDetailsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Exercise GIF
                if let details = viewModel.exerciseDetails {
                    AsyncImage(url: URL(string: details.gifUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    
                    // Instructions
                    if details.instructions.isEmpty {
                        Text("No instructions available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(details.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text(instruction)
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView()
                        .frame(height: 200)
                }
            }
            .onAppear {
                if let details = viewModel.exerciseDetails {
                    print("DEBUG: Exercise instructions count: \(details.instructions.count)")
                    print("DEBUG: Exercise instructions: \(details.instructions)")
                }
            }
        }
    }
}

// MARK: - Leaderboard Tab
private struct LeaderboardTab: View {
    let exercise: ExerciseTemplate
    
    var body: some View {
        LeaderboardSection(exercise: exercise)
            .padding(.vertical)
    }
}

// MARK: - Supporting Views
private struct PersonalRecordRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.blue)
        }
    }
}

// Add LeaderboardSection at the top of the file
struct LeaderboardSection: View {
    let exercise: ExerciseTemplate
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Tabs
            VStack(spacing: 8) {
                // Text(exercise.name.capitalized)
                //     .font(.headline)
                //     .padding(.horizontal)
                
                HStack(spacing: 0) {
                    LeaderboardTabButton(title: "Overall", selectedTab: $viewModel.selectedTab)
                    LeaderboardTabButton(title: "Following", selectedTab: $viewModel.selectedTab)
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Leaderboard header
            HStack {
                Text("ATHLETE")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("ONE REP MAX")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Text("Loading records...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let error = viewModel.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.leaderboardEntries.isEmpty {
                VStack(spacing: 20) {
                    Text(viewModel.selectedTab == "Following" ? "No records from people you follow" : "No records yet")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    if viewModel.selectedTab == "Following" {
                        NavigationLink(destination: Text("Find Friends")) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Find Friends")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: { showShareSheet = true }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Invite a Friend")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(viewModel.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                            HStack {
                                NavigationLink(destination: ProfileView(userId: entry.userId)) {
                                    HStack {
                                        AsyncImage(url: URL(string: entry.userProfileImageUrl ?? "")) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        
                                        VStack(alignment: .leading) {
                                            Text(entry.username)
                                                .font(.headline)
                                            Text(formatDate(entry.date))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("\(Int(entry.weight))lbs")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            // Medal for top 3
                                            if index < 3 {
                                                Image(systemName: getMedalSymbol(for: index))
                                                    .foregroundColor(getMedalColor(for: index))
                                                    .font(.title2)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            if index < viewModel.leaderboardEntries.count - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Check out my workout progress on Spot! Download the app and let's compete: https://spotapp.com"])
        }
        .task {
            print("DEBUG: Initial leaderboard fetch for exercise: \(exercise.name)")
            await viewModel.fetchLeaderboard(for: exercise.name)
        }
        .onChange(of: viewModel.selectedTab) { _ in
            Task {
                print("DEBUG: Refreshing leaderboard for exercise: \(exercise.name)")
                await viewModel.fetchLeaderboard(for: exercise.name)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getMedalSymbol(for index: Int) -> String {
        switch index {
        case 0: return "medal.fill"
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        default: return ""
        }
    }
    
    private func getMedalColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .brown
        default: return .clear
        }
    }
}

private struct LeaderboardTabButton: View {
    let title: String
    @Binding var selectedTab: String
    
    var body: some View {
        Button(action: {
            selectedTab = title
        }) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedTab == title ? Color.blue : Color.clear)
                .foregroundColor(selectedTab == title ? .white : .primary)
        }
    }
}

class LeaderboardViewModel: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTab = "Overall"
    private let db = Firestore.firestore()
    private var allEntries: [LeaderboardEntry] = []
    private let prService = PersonalRecordService()
    
    struct LeaderboardEntry: Identifiable {
        let id: String
        let userId: String
        let username: String
        let userProfileImageUrl: String?
        let weight: Double
        let date: Date
    }
    
    @MainActor
    func fetchLeaderboard(for exerciseName: String) async {
        isLoading = true
        error = nil
        allEntries = []
        leaderboardEntries = []
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                error = "Not logged in"
                isLoading = false
                return
            }
            
            print("DEBUG: Fetching leaderboard for exercise: \(exerciseName)")
            print("DEBUG: Current user ID: \(currentUserId)")
            
            // First get the current user's data and following list
            let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
            guard let currentUser = try? currentUserDoc.data(as: User.self) else {
                error = "Could not load user data"
                isLoading = false
                return
            }
            
            print("DEBUG: Current user follows: \(currentUser.followingIds)")
            
            // Get current user's PR
            if let currentUserPR = try await prService.getPR(userId: currentUserId, exerciseName: exerciseName) {
                print("DEBUG: Found PR for current user: \(currentUserPR.displayText)")
                let entry = LeaderboardEntry(
                    id: UUID().uuidString,
                    userId: currentUserId,
                    username: currentUser.username,
                    userProfileImageUrl: currentUser.profileImageUrl,
                    weight: currentUserPR.oneRepMax,
                    date: currentUserPR.date
                )
                allEntries.append(entry)
            }
            
            // Get PRs for followed users
            for followedId in currentUser.followingIds {
                print("DEBUG: Checking PR for followed user: \(followedId)")
                if let followedUserDoc = try? await db.collection("users").document(followedId).getDocument(),
                   let followedUser = try? followedUserDoc.data(as: User.self),
                   let followedPR = try await prService.getPR(userId: followedId, exerciseName: exerciseName) {
                    print("DEBUG: Found PR for followed user \(followedUser.username): \(followedPR.displayText)")
                    let entry = LeaderboardEntry(
                        id: UUID().uuidString,
                        userId: followedId,
                        username: followedUser.username,
                        userProfileImageUrl: followedUser.profileImageUrl,
                        weight: followedPR.oneRepMax,
                        date: followedPR.date
                    )
                    allEntries.append(entry)
                }
            }
            
            // Sort by weight descending
            allEntries = allEntries.sorted { $0.weight > $1.weight }
            print("DEBUG: Total entries found: \(allEntries.count)")
            
            // Filter based on selected tab
            updateLeaderboardEntries(currentUserId: currentUserId, followingIds: currentUser.followingIds)
            
        } catch {
            self.error = error.localizedDescription
            print("Error fetching leaderboard: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func updateLeaderboardEntries(currentUserId: String, followingIds: [String]) {
        switch selectedTab {
        case "Following":
            // Show only entries from users being followed and the current user
            leaderboardEntries = allEntries.filter { entry in
                entry.userId == currentUserId || followingIds.contains(entry.userId)
            }
            print("DEBUG: Filtered to \(leaderboardEntries.count) following entries")
        default: // "Overall"
            leaderboardEntries = allEntries
            print("DEBUG: Showing all \(leaderboardEntries.count) entries")
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailsView(exercise: ExerciseTemplate(
            id: "1",
            name: "Bench Press",
            bodyPart: "chest",
            equipment: "barbell",
            gifUrl: "",
            target: "chest",
            secondaryMuscles: ["triceps", "shoulders"],
            instructions: [
                "Lie on the bench.",
                "Extend your arms and grab the bar evenly, having your hands slightly more than shoulder-width apart.",
                "Bring your shoulder blades back and dig them into the bench.",
                "Arch your lower back and plant your feet flat on the floor.",
                "Take a breath, unrack the bar, and bring it over your chest.",
                "Inhale again and lower the barbell to your lower chest, tapping it slightly."
            ]
        ))
    }
} 
