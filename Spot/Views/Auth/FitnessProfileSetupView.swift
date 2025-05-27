import SwiftUI

struct FitnessProfileSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var signUpData: SignUpData
    
    @State private var weightString: String = ""
    @State private var feet: String = "5"  // Default values to avoid invalid selection
    @State private var inches: String = "0"
    @State private var showAlert = false
    @State private var errorMessage = ""
    @State private var showNextStep = false
    
    private let sexOptions = ["male", "female", "other", "prefer not to say"]
    private let feetRange = Array(1...8)
    private let inchesRange = Array(0...11)
    
    // Format weight for display
    private var displayWeight: String {
        if let weight = signUpData.weight {
            return String(format: "%.1f", weight)
        }
        return ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Fitness Profile")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.top)
                        .padding(.horizontal)
                    
                    Text("We use this information to provide personalized analytics and recommendations")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                // Basic Information Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("BASIC INFORMATION")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Sex Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sex")
                            .font(.headline)
                        
                        Picker("Sex", selection: $signUpData.sex) {
                            ForEach(sexOptions, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Measurement System
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Measurement System")
                            .font(.headline)
                        
                        Picker("System", selection: $signUpData.measurementSystem) {
                            Text("Imperial (lbs, ft)").tag(UserFitnessProfile.MeasurementSystem.imperial)
                            Text("Metric (kg, cm)").tag(UserFitnessProfile.MeasurementSystem.metric)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Weight Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            TextField("Weight", text: $weightString)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 120)
                                .onChange(of: weightString) { newValue in
                                    if let weight = Double(newValue) {
                                        signUpData.weight = weight
                                    }
                                }
                            
                            Text(signUpData.measurementSystem == .imperial ? "lbs" : "kg")
                                .foregroundColor(.gray)
                                .frame(width: 40)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Height Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height")
                            .font(.headline)
                        
                        if signUpData.measurementSystem == .imperial {
                            HStack(spacing: 16) {
                                // Feet
                                VStack(alignment: .leading) {
                                    Text("Feet")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Picker("Feet", selection: $feet) {
                                        ForEach(feetRange, id: \.self) { ft in
                                            Text("\(ft)'").tag(String(ft))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                }
                                
                                // Inches
                                VStack(alignment: .leading) {
                                    Text("Inches")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Picker("Inches", selection: $inches) {
                                        ForEach(inchesRange, id: \.self) { inch in
                                            Text("\(inch)\"").tag(String(inch))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                }
                            }
                            .onChange(of: feet) { _ in updateHeight() }
                            .onChange(of: inches) { _ in updateHeight() }
                        } else {
                            HStack(spacing: 12) {
                                TextField("Height", text: Binding(
                                    get: { displayWeight },
                                    set: { newValue in
                                        if let height = Double(newValue) {
                                            signUpData.height = height
                                        }
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 120)
                                
                                Text("cm")
                                    .foregroundColor(.gray)
                                    .frame(width: 40)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                Text("You can always update this information later in your profile settings")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // Continue Button
                Button {
                    saveProfile()
                } label: {
                    Text("Continue to Goals")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showNextStep) {
            NavigationStack {
                GoalSettingView(signUpData: signUpData)
            }
        }
        .onAppear {
            // Initialize strings from existing values if any
            if let weight = signUpData.weight {
                weightString = String(format: "%.1f", weight)
            }
            if let height = signUpData.height, signUpData.measurementSystem == .imperial {
                let totalInches = Int(height)
                feet = String(totalInches / 12)
                inches = String(totalInches % 12)
            }
        }
    }
    
    private func updateHeight() {
        guard let feetValue = Double(feet),
              let inchesValue = Double(inches) else {
            return
        }
        
        let totalInches = (feetValue * 12) + inchesValue
        signUpData.height = totalInches
    }
    
    private func saveProfile() {
        // Validate weight
        guard let weight = signUpData.weight, weight > 0 else {
            errorMessage = "Please enter a valid weight"
            showAlert = true
            return
        }
        
        // Validate height
        guard let height = signUpData.height, height > 0 else {
            errorMessage = "Please enter a valid height"
            showAlert = true
            return
        }
        
        showNextStep = true
    }
} 
