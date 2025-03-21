import SwiftUI
import FirebaseFirestore

struct TrophyCaseView: View {
    let userId: String
    @StateObject private var viewModel = TrophyCaseViewModel()
    @State private var selectedFilter: TrophyFilter = .all
    
    enum TrophyFilter {
        case all, personalRecords, challenges
    }
    
    var body: some View {
        ScrollView {
            if viewModel.personalRecords.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No personal records yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Filter buttons
                    Picker("Trophy Filter", selection: $selectedFilter) {
                        Text("All").tag(TrophyFilter.all)
                        Text("Personal Records").tag(TrophyFilter.personalRecords)
                        Text("Challenges").tag(TrophyFilter.challenges)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Trophy grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.personalRecords.filter { record in
                            selectedFilter == .all || selectedFilter == .personalRecords
                        }) { pr in
                            PersonalRecordCard(record: pr)
                        }
                        
                        // Placeholder for future challenge trophies
                        if selectedFilter == .all || selectedFilter == .challenges {
                            // Add challenge trophies here when implemented
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Trophy Case")
        .task {
            guard !userId.isEmpty else { return }
            await viewModel.loadPersonalRecords(for: userId)
        }
    }
}

struct PersonalRecordCard: View {
    let record: PersonalRecordDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Spacer()
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(record.exerciseName)
                .font(.headline)
                .lineLimit(2)
            
            Text("\(String(format: "%.1f", record.weight))lbs × \(record.reps)")
                .font(.subheadline)
            
            Text("1RM: \(String(format: "%.1f", record.oneRepMax))lbs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// View Model for Trophy Case
@MainActor
class TrophyCaseViewModel: ObservableObject {
    @Published var personalRecords: [PersonalRecordDisplay] = []
    private let db = Firestore.firestore()
    
    func loadPersonalRecords(for userId: String) async {
        do {
            let prService = PersonalRecordService()
            let records = try await prService.getAllPRs(userId: userId)
            
            // Convert to display models and sort by date
            self.personalRecords = records
                .map { PersonalRecordDisplay(from: $0) }
                .sorted { $0.date > $1.date }
        } catch {
            print("Error loading personal records: \(error)")
        }
    }
}

// Display model for Personal Records
struct PersonalRecordDisplay: Identifiable {
    let id: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let oneRepMax: Double
    let date: Date
    
    init(from record: PersonalRecord) {
        self.id = record.id
        self.exerciseName = record.exerciseName
        self.weight = record.weight
        self.reps = record.reps
        self.oneRepMax = record.oneRepMax
        self.date = record.date
    }
} 