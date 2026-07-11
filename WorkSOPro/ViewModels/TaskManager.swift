//
//  TaskManager.swift
//  WorkSOPro
//
//  ViewModel for managing tasks with AI prioritization
//

import Foundation
import Combine

class TaskManager: ObservableObject {
    // Large task sets or multiple already-important tasks are treated as high-impact
    // so AI reprioritization is forced through the thermal-aware queue.
    private static let highImpactTaskCountThreshold = 8

    @Published var tasks: [Task] = []
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let agentWorkerPool = ThermalAwareWorkerPool(maxConcurrentTasks: 1)
    
    init() {
        loadTasks()
        loadProjects()
    }
    
    // MARK: - Task Operations
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
        NotificationManager.shared.scheduleTaskReminder(for: task)
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func completeTask(_ task: Task) {
        var updatedTask = task
        updatedTask.status = .completed
        updatedTask.completedAt = Date()
        updateTask(updatedTask)
        
        // Track productivity metrics
        ProductivityTracker.shared.recordTaskCompletion(task: updatedTask)
    }
    
    func getTasks(for project: Project) -> [Task] {
        tasks.filter { $0.projectId == project.id }
    }
    
    func getTasksByPriority() -> [Task] {
        tasks.sorted { task1, task2 in
            if task1.priority.sortOrder != task2.priority.sortOrder {
                return task1.priority.sortOrder < task2.priority.sortOrder
            }
            // Secondary sort by due date
            if let date1 = task1.dueDate, let date2 = task2.dueDate {
                return date1 < date2
            }
            return task1.createdAt < task2.createdAt
        }
    }
    
    func getOverdueTasks() -> [Task] {
        tasks.filter { $0.isOverdue }
    }
    
    func getTodayTasks() -> [Task] {
        let calendar = Calendar.current
        let today = Date()
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        }
    }
    
    // MARK: - AI-Powered Prioritization
    
    func applyAIPrioritization() {
        isLoading = true
        let taskSnapshot = tasks
        let isHighImpactMode = taskSnapshot.count >= Self.highImpactTaskCountThreshold ||
            taskSnapshot.contains(where: { $0.priority == .high || $0.priority == .urgent })
        
        Task { [weak self] in
            guard let self = self else { return }

            await agentWorkerPool.executeTask(isHighImpactTask: isHighImpactMode) { [weak self] in
                guard let self = self else { return }
                let prioritizedTasks = Self.prioritizeTasks(taskSnapshot)

                await MainActor.run {
                    self.tasks = prioritizedTasks
                    self.saveTasks()
                    self.isLoading = false
                }
            }
        }
    }

    private static func prioritizeTasks(_ tasks: [Task]) -> [Task] {
        tasks.map { task in
            var prioritizedTask = task
            let score = calculatePriorityScore(for: task)

            if score > 80 {
                prioritizedTask.priority = .urgent
            } else if score > 60 {
                prioritizedTask.priority = .high
            } else if score > 40 {
                prioritizedTask.priority = .medium
            } else {
                prioritizedTask.priority = .low
            }
            
            return prioritizedTask
        }
    }
    
    private static func calculatePriorityScore(for task: Task) -> Int {
        var score = 0
        
        // Factor 1: Due date proximity (40 points)
        if let dueDate = task.dueDate {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 100
            if daysUntilDue < 0 {
                score += 40 // Overdue
            } else if daysUntilDue == 0 {
                score += 35 // Due today
            } else if daysUntilDue <= 3 {
                score += 30 // Due soon
            } else if daysUntilDue <= 7 {
                score += 20
            } else {
                score += 10
            }
        }
        
        // Factor 2: Current priority (30 points)
        score += (4 - task.priority.sortOrder) * 10
        
        // Factor 3: Subtask completion (15 points)
        if !task.subtasks.isEmpty {
            let completionPercentage = task.completionPercentage
            score += Int((100 - completionPercentage) / 100 * 15)
        }
        
        // Factor 4: Age of task (15 points)
        let daysOld = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        if daysOld > 7 {
            score += 15
        } else if daysOld > 3 {
            score += 10
        } else {
            score += 5
        }
        
        return min(100, score)
    }
    
    // MARK: - Project Operations
    
    func addProject(_ project: Project) {
        projects.append(project)
        saveProjects()
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        // Also delete associated tasks
        tasks.removeAll { $0.projectId == project.id }
        saveProjects()
        saveTasks()
    }
    
    // MARK: - Persistence
    
    private func loadTasks() {
        // In a real app, load from Core Data or CloudKit
        // For now, use sample data
        tasks = []
    }
    
    private func saveTasks() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func loadProjects() {
        // In a real app, load from Core Data or CloudKit
        projects = []
    }
    
    private func saveProjects() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
}
