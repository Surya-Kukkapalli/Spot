import SwiftUI

struct RestTimerSetupView: View {
    @Binding var isPresented: Bool
    let exerciseName: String
    let setNumber: Int
    let onStart: (TimeInterval) -> Void
    
    private let presetTimes: [TimeInterval] = [30, 60, 90, 120, 180]
    @State private var selectedTime: TimeInterval = 90
    @State private var customTime: TimeInterval = 90
    @State private var isCustom = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(presetTimes, id: \.self) { time in
                        HStack {
                            Text("\(Int(time)) seconds")
                            Spacer()
                            if selectedTime == time && !isCustom {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTime = time
                            isCustom = false
                        }
                    }
                } header: {
                    Text("Preset Times")
                }
                
                Section {
                    HStack {
                        Text("Custom")
                        Spacer()
                        if isCustom {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCustom = true
                        selectedTime = customTime
                    }
                    
                    if isCustom {
                        Stepper(value: $customTime, in: 5...600, step: 5) {
                            Text("\(Int(customTime)) seconds")
                        }
                        .onChange(of: customTime) { newValue in
                            selectedTime = newValue
                        }
                    }
                } header: {
                    Text("Custom Time")
                }
                
                Section {
                    Button {
                        isPresented = false
                        onStart(selectedTime)
                    } label: {
                        Text("Start Timer")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
} 