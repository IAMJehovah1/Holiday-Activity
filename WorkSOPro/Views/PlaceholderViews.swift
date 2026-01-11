//
//  PlaceholderViews.swift
//  WorkSOPro
//
//  Placeholder views for remaining app screens
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showAddTask = false
    
    var body: some View {
        NavigationView {
            List {
                if taskManager.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checkmark.circle",
                        description: Text("Create your first task to get started")
                    )
                } else {
                    ForEach(taskManager.getTasksByPriority()) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct ProjectsView: View {
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        NavigationView {
            List {
                if taskManager.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a project to organize your tasks")
                    )
                } else {
                    ForEach(taskManager.projects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            HStack {
                                Circle()
                                    .fill(project.color.color)
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text(project.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
        }
    }
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var taskManager: TaskManager
    
    var projectTasks: [Task] {
        taskManager.getTasks(for: project)
    }
    
    var body: some View {
        List {
            Section("Project Info") {
                Text(project.description)
                    .font(.body)
                
                if let goal = project.goal {
                    Label(goal, systemImage: "target")
                        .font(.subheadline)
                }
            }
            
            Section("Tasks") {
                if projectTasks.isEmpty {
                    Text("No tasks in this project")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(projectTasks) { task in
                        TaskRowView(task: task)
                    }
                }
            }
        }
        .navigationTitle(project.name)
    }
}

struct WellBeingView: View {
    @EnvironmentObject var wellBeingManager: WellBeingManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Well-Being Score
                    VStack(spacing: 12) {
                        Text("Well-Being Score")
                            .font(.headline)
                        
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 20)
                                .frame(width: 150, height: 150)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(wellBeingManager.currentMetrics.wellBeingScore) / 100)
                                .stroke(scoreColor(wellBeingManager.currentMetrics.wellBeingScore), lineWidth: 20)
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(wellBeingManager.currentMetrics.wellBeingScore)")
                                .font(.system(size: 48, weight: .bold))
                        }
                    }
                    .padding()
                    
                    // Metrics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MetricCard(title: "Steps", value: "\(wellBeingManager.currentMetrics.stepsCount)", icon: "figure.walk", color: .green)
                        MetricCard(title: "Exercise", value: "\(wellBeingManager.currentMetrics.exerciseMinutes)m", icon: "flame", color: .orange)
                        MetricCard(title: "Mindful", value: "\(wellBeingManager.currentMetrics.mindfulMinutes)m", icon: "brain", color: .purple)
                        MetricCard(title: "Breaks", value: "\(wellBeingManager.currentMetrics.breaksCount)", icon: "pause.circle", color: .blue)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Well-Being")
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .yellow
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct AnalyticsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var wellBeingManager: WellBeingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            List {
                Section("Productivity") {
                    AnalyticRow(title: "Tasks Completed", value: "\(ProductivityTracker.shared.getDailyProductivityReport().tasksCompleted)", icon: "checkmark.circle", color: .green)
                    AnalyticRow(title: "Focus Time", value: "\(ProductivityTracker.shared.getDailyProductivityReport().focusMinutes) min", icon: "brain", color: .purple)
                    AnalyticRow(title: "Productivity Score", value: String(format: "%.0f", ProductivityTracker.shared.getDailyProductivityReport().productivityScore), icon: "chart.line.uptrend.xyaxis", color: .blue)
                }
                
                Section("Well-Being") {
                    AnalyticRow(title: "Well-Being Score", value: "\(wellBeingManager.currentMetrics.wellBeingScore)", icon: "heart.fill", color: .red)
                    AnalyticRow(title: "Stress Level", value: wellBeingManager.currentMetrics.stressLevel.rawValue, icon: "waveform.path.ecg", color: wellBeingManager.currentMetrics.stressLevel.color)
                }
                
                if subscriptionManager.hasFeature(.profitAnalytics) {
                    Section("Business Impact") {
                        AnalyticRow(title: "Time Saved", value: "2.5 hrs", icon: "clock", color: .orange)
                        AnalyticRow(title: "ROI", value: "$450", icon: "dollarsign.circle", color: .green)
                    }
                }
            }
            .navigationTitle("Analytics")
        }
    }
}

struct AnalyticRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = appState.currentUser {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Subscription") {
                    HStack {
                        Text("Current Plan")
                        Spacer()
                        Text(subscriptionManager.currentSubscription.tier.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Upgrade Plan") {
                        SubscriptionUpgradeView()
                    }
                }
                
                Section("Preferences") {
                    NavigationLink("Notifications") {
                        Text("Notification Settings")
                    }
                    
                    NavigationLink("Wellness Reminders") {
                        Text("Wellness Reminder Settings")
                    }
                }
                
                Section {
                    Button("Sign Out") {
                        appState.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SubscriptionUpgradeView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        List {
            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                Section(tier.displayName) {
                    if tier != .free {
                        HStack {
                            Text("Price")
                            Spacer()
                            Text("$\(tier.monthlyPrice)/month")
                                .fontWeight(.semibold)
                        }
                    }
                    
                    ForEach(tier.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                    
                    if tier != subscriptionManager.currentSubscription.tier {
                        Button(tier == .free ? "Downgrade" : "Upgrade") {
                            subscriptionManager.upgradeTo(tier: tier)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Choose Plan")
    }
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "briefcase.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            Text("Welcome to WorkSOPro")
                .font(.largeTitle)
                .bold()
            
            Text("Boost productivity while maintaining well-being")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Get Started") {
                appState.showOnboarding = false
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .padding()
    }
}
