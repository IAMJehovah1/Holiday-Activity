//
//  NotificationManager.swift
//  WorkSOPro
//
//  Service for managing notifications and reminders
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification authorization granted")
            } else if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }
    
    func scheduleTaskReminder(for task: Task) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due Soon"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        
        // Schedule 1 hour before due date
        let reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendBreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for a Break"
        content.body = "You've been working for 90 minutes. Take a 5-minute break to refresh."
        content.sound = .default
        content.categoryIdentifier = "BREAK_REMINDER"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendHydrationReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Stay Hydrated"
        content.body = "Remember to drink water!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleRecurringReminder(type: ReminderType, interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        
        switch type {
        case .hydration:
            content.title = "Stay Hydrated"
            content.body = "Time to drink some water!"
        case .stretch:
            content.title = "Time to Stretch"
            content.body = "Take a moment to stretch and move around."
        case .eyeBreak:
            content.title = "Eye Break"
            content.body = "Look away from your screen for 20 seconds."
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    enum ReminderType: String {
        case hydration = "HYDRATION_REMINDER"
        case stretch = "STRETCH_REMINDER"
        case eyeBreak = "EYE_BREAK_REMINDER"
    }
}
