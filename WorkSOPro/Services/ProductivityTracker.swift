//
//  ProductivityTracker.swift
//  WorkSOPro
//
//  Service for tracking productivity metrics
//

import Foundation

class ProductivityTracker {
    static let shared = ProductivityTracker()
    
    private var sessionStartTime: Date?
    private var focusSessionActive = false
    private var productivityLog: [ProductivityEntry] = []
    
    private init() {}
    
    struct ProductivityEntry: Codable {
        let timestamp: Date
        let type: EntryType
        let taskId: UUID?
        let durationMinutes: Int?
        let metadata: [String: String]?
        
        enum EntryType: String, Codable {
            case taskStarted
            case taskCompleted
            case taskPaused
            case focusSessionStarted
            case focusSessionEnded
            case breakTaken
            case meetingAttended
        }
    }
    
    // MARK: - Session Tracking
    
    func startFocusSession(duration: Int = 25) {
        sessionStartTime = Date()
        focusSessionActive = true
        
        logEntry(ProductivityEntry(
            timestamp: Date(),
            type: .focusSessionStarted,
            taskId: nil,
            durationMinutes: duration,
            metadata: nil
        ))
    }
    
    func endFocusSession() {
        guard let startTime = sessionStartTime else { return }
        
        let duration = Int(Date().timeIntervalSince(startTime) / 60)
        focusSessionActive = false
        
        logEntry(ProductivityEntry(
            timestamp: Date(),
            type: .focusSessionEnded,
            taskId: nil,
            durationMinutes: duration,
            metadata: nil
        ))
        
        sessionStartTime = nil
    }
    
    // MARK: - Task Tracking
    
    func recordTaskCompletion(task: Task) {
        let duration = task.actualMinutes ?? 0
        
        logEntry(ProductivityEntry(
            timestamp: Date(),
            type: .taskCompleted,
            taskId: task.id,
            durationMinutes: duration,
            metadata: [
                "priority": task.priority.rawValue,
                "title": task.title
            ]
        ))
    }
    
    func recordBreak(duration: Int) {
        logEntry(ProductivityEntry(
            timestamp: Date(),
            type: .breakTaken,
            taskId: nil,
            durationMinutes: duration,
            metadata: nil
        ))
    }
    
    func recordMeeting(durationMinutes: Int, wasProductive: Bool) {
        logEntry(ProductivityEntry(
            timestamp: Date(),
            type: .meetingAttended,
            taskId: nil,
            durationMinutes: durationMinutes,
            metadata: ["productive": String(wasProductive)]
        ))
    }
    
    // MARK: - Analytics
    
    func getDailyProductivityReport(for date: Date = Date()) -> DailyReport {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let todayEntries = productivityLog.filter { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
        }
        
        let tasksCompleted = todayEntries.filter { $0.type == .taskCompleted }.count
        let totalFocusMinutes = todayEntries
            .filter { $0.type == .focusSessionEnded }
            .compactMap { $0.durationMinutes }
            .reduce(0, +)
        
        let totalBreakMinutes = todayEntries
            .filter { $0.type == .breakTaken }
            .compactMap { $0.durationMinutes }
            .reduce(0, +)
        
        let meetingMinutes = todayEntries
            .filter { $0.type == .meetingAttended }
            .compactMap { $0.durationMinutes }
            .reduce(0, +)
        
        return DailyReport(
            date: date,
            tasksCompleted: tasksCompleted,
            focusMinutes: totalFocusMinutes,
            breakMinutes: totalBreakMinutes,
            meetingMinutes: meetingMinutes
        )
    }
    
    struct DailyReport {
        let date: Date
        let tasksCompleted: Int
        let focusMinutes: Int
        let breakMinutes: Int
        let meetingMinutes: Int
        
        var productivityScore: Double {
            let focusScore = min(100, Double(focusMinutes) / 4.0) // 400 minutes = 100
            let taskScore = min(100, Double(tasksCompleted) * 10.0)
            let breakBalance = abs(Double(breakMinutes) - 60) / 60.0 // Optimal: 60 minutes
            let breakScore = max(0, 100 - (breakBalance * 50))
            
            return (focusScore * 0.4 + taskScore * 0.4 + breakScore * 0.2)
        }
    }
    
    private func logEntry(_ entry: ProductivityEntry) {
        productivityLog.append(entry)
        // In a real app, persist to Core Data or CloudKit
    }
}
