//
//  ContentView.swift
//  WorkSOPro
//
//  Main app view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var wellBeingManager: WellBeingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppState.Tab.dashboard)
            
            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }
                .tag(AppState.Tab.tasks)
            
            LoungeView()
                .tabItem {
                    Label("Lounge", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(AppState.Tab.lounge)
            
            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(AppState.Tab.projects)
            
            WellBeingView()
                .tabItem {
                    Label("Well-Being", systemImage: "heart.fill")
                }
                .tag(AppState.Tab.wellBeing)
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppState.Tab.analytics)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppState.Tab.settings)
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView()
        }
        .alert("Time for a Break!", isPresented: $wellBeingManager.shouldShowBreakReminder) {
            Button("Take Break") {
                wellBeingManager.recordBreak()
            }
            Button("Remind Later", role: .cancel) {}
        } message: {
            Text("You've been working for 90 minutes. Take a 5-minute break to refresh and maintain productivity.")
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var wellBeingManager: WellBeingManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Good \(timeOfDay)")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Ready to be productive?")
                                .font(.largeTitle)
                                .bold()
                        }
                        Spacer()
                    }
                    .padding()
                    
                    // Quick Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Tasks Today",
                            value: "\(taskManager.getTodayTasks().count)",
                            icon: "checkmark.circle.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Well-Being",
                            value: "\(wellBeingManager.currentMetrics.wellBeingScore)",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        StatCard(
                            title: "Focus Time",
                            value: "\(ProductivityTracker.shared.getDailyProductivityReport().focusMinutes)m",
                            icon: "brain.head.profile",
                            color: .purple
                        )
                        
                        StatCard(
                            title: "Completed",
                            value: "\(ProductivityTracker.shared.getDailyProductivityReport().tasksCompleted)",
                            icon: "star.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Overdue Tasks
                    if !taskManager.getOverdueTasks().isEmpty {
                        VStack(alignment: .leading) {
                            Text("Overdue Tasks")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(taskManager.getOverdueTasks().prefix(3)) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                    
                    // Today's Tasks
                    VStack(alignment: .leading) {
                        Text("Today's Tasks")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if taskManager.getTodayTasks().isEmpty {
                            Text("No tasks scheduled for today")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(taskManager.getTodayTasks().prefix(5)) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("WorkSOPro")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TaskRowView: View {
    let task: Task
    
    var body: some View {
        HStack {
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.body)
                
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == .completed ? .green : .secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(TaskManager())
        .environmentObject(WellBeingManager())
        .environmentObject(SubscriptionManager())
}
