import SwiftUI

struct GoalSettingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var signUpData: SignUpData
    
    @State private var showAlert = false
    @State private var errorMessage = ""
    @State private var showHome = false
    @State private var isLoading = false
    @State private var goalDescription: String = ""
    
    private let experienceLevels: [(level: UserFitnessProfile.ExperienceLevel, description: String)] = [
        (.beginner, "New to fitness or getting back into it"),
        (.intermediate, "Regular workout routine for 6+ months"),
        (.advanced, "Experienced with various workout types")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Fitness Goals")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.top)
                        .padding(.horizontal)
                    
                    Text("Let us know your goals and experience so we can provide AI-powered recommendations")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // AI Goal Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Describe Your Goals")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text("Tell us about your fitness goals in your own words. Our AI will create a personalized program based on your description.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            TextEditor(text: $goalDescription)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        
                        Text("Or select from common goals below:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        // Experience Level
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Experience Level")
                                .font(.headline)
                            
                            ForEach(experienceLevels, id: \.level) { item in
                                Button {
                                    signUpData.experienceLevel = item.level
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.level.rawValue.capitalized)
                                                .font(.subheadline)
                                                .bold()
                                            Text(item.description)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        if signUpData.experienceLevel == item.level {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(signUpData.experienceLevel == item.level ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Goals
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Goals")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(FitnessGoal.GoalType.allCases, id: \.self) { goalType in
                                    Button {
                                        if signUpData.selectedGoalTypes.contains(goalType) {
                                            signUpData.selectedGoalTypes.remove(goalType)
                                        } else {
                                            signUpData.selectedGoalTypes.insert(goalType)
                                        }
                                    } label: {
                                        Text(goalType.rawValue)
                                            .font(.subheadline)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(signUpData.selectedGoalTypes.contains(goalType) ? Color.blue : Color(.systemGray6))
                                            )
                                            .foregroundColor(signUpData.selectedGoalTypes.contains(goalType) ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Preferred Workout Types
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Preferred Workout Types")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(UserFitnessProfile.WorkoutType.allCases, id: \.self) { workoutType in
                                    Button {
                                        if signUpData.selectedWorkoutTypes.contains(workoutType) {
                                            signUpData.selectedWorkoutTypes.remove(workoutType)
                                        } else {
                                            signUpData.selectedWorkoutTypes.insert(workoutType)
                                        }
                                    } label: {
                                        Text(workoutType.rawValue)
                                            .font(.subheadline)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(signUpData.selectedWorkoutTypes.contains(workoutType) ? Color.blue : Color(.systemGray6))
                                            )
                                            .foregroundColor(signUpData.selectedWorkoutTypes.contains(workoutType) ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // AI Adaptability Info
                        VStack(spacing: 8) {
                            Text("Our AI-Powered Workout Programs")
                                .font(.headline)
                            Text("Your workout programs will dynamically adapt based on your training style, progress, and habits. Provide feedback as you go to help refine and optimize your programs.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .padding(.horizontal)
                    }
                }
                
                // Create Account Button
                Button {
                    createAccount()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isFormValid ? Color.red : Color.gray)
                .cornerRadius(12)
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, 24)
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
        .fullScreenCover(isPresented: $showHome) {
            MainTabView()
                .environmentObject(authViewModel)
        }
    }
    
    private var isFormValid: Bool {
        !signUpData.selectedGoalTypes.isEmpty && !signUpData.selectedWorkoutTypes.isEmpty
    }
    
    private func createAccount() {
        isLoading = true
        
        // Store the goal description in SignUpData
        signUpData.goalDescription = goalDescription
        
        Task {
            do {
                // Create the user account
                try await authViewModel.createUser(
                    email: signUpData.email,
                    password: signUpData.password,
                    username: signUpData.username,
                    firstName: signUpData.firstName,
                    lastName: signUpData.lastName
                )
                
                // Create and update the fitness profile
                let fitnessProfile = signUpData.createFitnessProfile()
                try await authViewModel.updateFitnessProfile(fitnessProfile)
                
                await MainActor.run {
                    isLoading = false
                    showHome = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
} 
