//
//  Task.swift
//  WorkSOPro
//
//  Model representing a task/work item
//

import Foundation
import SwiftUI

struct Task: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var priority: Priority
    var status: TaskStatus
    var dueDate: Date?
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var projectId: UUID?
    var tags: [String]
    var createdAt: Date
    var completedAt: Date?
    var subtasks: [Subtask]
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .urgent: return .red
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .urgent: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }
    
    enum TaskStatus: String, Codable, CaseIterable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case completed = "Completed"
        case archived = "Archived"
    }
    
    struct Subtask: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        var isCompleted: Bool
        
        init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        priority: Priority = .medium,
        status: TaskStatus = .todo,
        dueDate: Date? = nil,
        estimatedMinutes: Int? = nil,
        projectId: UUID? = nil,
        tags: [String] = [],
        subtasks: [Subtask] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = nil
        self.projectId = projectId
        self.tags = tags
        self.createdAt = Date()
        self.completedAt = nil
        self.subtasks = subtasks
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, status != .completed else {
            return false
        }
        return dueDate < Date()
    }
    
    var completionPercentage: Double {
        guard !subtasks.isEmpty else { return status == .completed ? 100 : 0 }
        let completed = subtasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subtasks.count) * 100
    }
}
