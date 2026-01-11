//
//  WinddownActivitiesView.swift
//  WorkSOPro
//
//  View for browsing and starting winddown activities
//

import SwiftUI

struct WinddownActivitiesView: View {
    @ObservedObject var loungeManager: LoungeManager
    @EnvironmentObject var wellBeingManager: WellBeingManager
    @State private var selectedCategory: WinddownActivity.ActivityType?
    
    var filteredActivities: [WinddownActivity] {
        if let category = selectedCategory {
            return loungeManager.winddownActivities.filter { $0.type == category }
        }
        return loungeManager.winddownActivities
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Winddown Activities")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Take a break and recharge with guided activities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Stress-based recommendation
                if let recommended = loungeManager.getRecommendedActivity(basedOnStress: wellBeingManager.currentMetrics.stressLevel) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended for You")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        RecommendedActivityCard(activity: recommended, loungeManager: loungeManager)
                            .padding(.horizontal)
                    }
                }
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(WinddownActivity.ActivityType.allCases, id: \.self) { type in
                            CategoryButton(
                                title: type.rawValue,
                                icon: type.icon,
                                color: type.color,
                                isSelected: selectedCategory == type,
                                action: { selectedCategory = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Activities Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredActivities) { activity in
                        NavigationLink(destination: WinddownActivityDetailView(activity: activity, loungeManager: loungeManager)) {
                            WinddownActivityCard(activity: activity)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Popular activities
                if selectedCategory == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Most Popular")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(loungeManager.getPopularWinddownActivities()) { activity in
                            NavigationLink(destination: WinddownActivityDetailView(activity: activity, loungeManager: loungeManager)) {
                                PopularActivityRow(activity: activity)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Winddown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryButton: View {
    let title: String
    var icon: String?
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct RecommendedActivityCard: View {
    let activity: WinddownActivity
    @ObservedObject var loungeManager: LoungeManager
    
    var body: some View {
        NavigationLink(destination: WinddownActivityDetailView(activity: activity, loungeManager: loungeManager)) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(activity.type.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: activity.type.icon)
                        .font(.title2)
                        .foregroundColor(activity.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(activity.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("\(activity.durationMinutes) min")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(activity.type.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(activity.type.color.opacity(0.3), lineWidth: 2)
                    )
            )
        }
    }
}

struct WinddownActivityCard: View {
    let activity: WinddownActivity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(activity.type.color.opacity(0.2))
                    .frame(height: 120)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(activity.durationMinutes) min")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                    Text("\(activity.completionCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct PopularActivityRow: View {
    let activity: WinddownActivity
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: activity.type.icon)
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "clock")
                    Text("\(activity.durationMinutes) min")
                    
                    Spacer().frame(width: 12)
                    
                    Image(systemName: "person.3")
                    Text("\(activity.completionCount) completed")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct WinddownActivityDetailView: View {
    let activity: WinddownActivity
    @ObservedObject var loungeManager: LoungeManager
    @EnvironmentObject var appState: AppState
    @State private var isActive = false
    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss
    
    init(activity: WinddownActivity, loungeManager: LoungeManager) {
        self.activity = activity
        self.loungeManager = loungeManager
        _timeRemaining = State(initialValue: activity.durationMinutes * 60)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Section
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [activity.type.color.opacity(0.3), activity.type.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                    
                    VStack(spacing: 16) {
                        Image(systemName: activity.type.icon)
                            .font(.system(size: 60))
                            .foregroundColor(activity.type.color)
                        
                        if isActive {
                            Text(timeString(from: timeRemaining))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(activity.type.color)
                        }
                    }
                }
                .padding()
                
                // Title and Description
                VStack(alignment: .leading, spacing: 12) {
                    Text(activity.title)
                        .font(.title)
                        .bold()
                    
                    Text(activity.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Label("\(activity.durationMinutes) min", systemImage: "clock")
                        Label("\(activity.completionCount) completed", systemImage: "checkmark.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Instructions")
                        .font(.headline)
                    
                    ForEach(Array(activity.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(activity.type.color.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(activity.type.color)
                            }
                            
                            Text(instruction)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Start/Stop Button
                Button {
                    if isActive {
                        stopActivity()
                    } else {
                        startActivity()
                    }
                } label: {
                    Text(isActive ? "Complete Activity" : "Start Activity")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(activity.type.color)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                
                if isActive {
                    Button("Cancel") {
                        cancelActivity()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(activity.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startActivity() {
        isActive = true
        loungeManager.startWinddownActivity(activity)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopActivity()
            }
        }
    }
    
    private func stopActivity() {
        isActive = false
        timer?.invalidate()
        timer = nil
        
        if let userId = appState.currentUser?.id.uuidString {
            loungeManager.completeWinddownActivity(activity, userId: userId)
        }
        
        // Show completion message
        dismiss()
    }
    
    private func cancelActivity() {
        isActive = false
        timer?.invalidate()
        timer = nil
        timeRemaining = activity.durationMinutes * 60
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct CreateLoungeView: View {
    @ObservedObject var loungeManager: LoungeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: Lounge.LoungeType = .general
    @State private var selectedColor: Lounge.LoungeColor = .blue
    @State private var isPrivate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Lounge Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(Lounge.LoungeType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(Lounge.LoungeColor.allCases, id: \.self) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                }
                
                Section("Privacy") {
                    Toggle("Private Lounge", isOn: $isPrivate)
                }
            }
            .navigationTitle("Create Lounge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createLounge()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createLounge() {
        let lounge = Lounge(
            name: name,
            description: description,
            type: selectedType,
            isPrivate: isPrivate,
            loungeColor: selectedColor
        )
        
        loungeManager.createLounge(lounge)
        dismiss()
    }
}

struct WellnessResourcesView: View {
    var body: some View {
        List {
            Section("Mental Health") {
                ResourceRow(title: "Stress Management Tips", icon: "brain.head.profile", color: .purple)
                ResourceRow(title: "Mindfulness Techniques", icon: "sparkles", color: .blue)
                ResourceRow(title: "Work-Life Balance", icon: "scale.3d", color: .green)
            }
            
            Section("Physical Wellness") {
                ResourceRow(title: "Ergonomic Setup Guide", icon: "desktopcomputer", color: .orange)
                ResourceRow(title: "Desk Exercises", icon: "figure.walk", color: .red)
                ResourceRow(title: "Eye Care Tips", icon: "eye", color: .cyan)
            }
            
            Section("Nutrition") {
                ResourceRow(title: "Healthy Snack Ideas", icon: "leaf", color: .green)
                ResourceRow(title: "Hydration Reminders", icon: "drop", color: .blue)
                ResourceRow(title: "Meal Planning", icon: "fork.knife", color: .orange)
            }
            
            Section("Sleep") {
                ResourceRow(title: "Sleep Hygiene", icon: "bed.double", color: .indigo)
                ResourceRow(title: "Wind Down Routines", icon: "moon", color: .purple)
                ResourceRow(title: "Sleep Tracking", icon: "chart.line.uptrend.xyaxis", color: .blue)
            }
        }
        .navigationTitle("Wellness Resources")
    }
}

struct ResourceRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
        }
    }
}

#Preview {
    NavigationView {
        WinddownActivitiesView(loungeManager: LoungeManager())
            .environmentObject(WellBeingManager())
            .environmentObject(AppState())
    }
}
