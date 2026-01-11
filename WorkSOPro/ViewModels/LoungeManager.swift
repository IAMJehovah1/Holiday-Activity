//
//  LoungeManager.swift
//  WorkSOPro
//
//  ViewModel for managing lounges, communication, and winddown activities
//

import Foundation
import Combine
import SwiftUI

class LoungeManager: ObservableObject {
    @Published var lounges: [Lounge] = []
    @Published var messages: [UUID: [LoungeMessage]] = [:] // Lounge ID -> Messages
    @Published var winddownActivities: [WinddownActivity] = []
    @Published var currentActivity: WinddownActivity?
    @Published var isLoadingMessages = false
    @Published var unreadCounts: [UUID: Int] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadLounges()
        loadWinddownActivities()
        setupDefaultLounges()
    }
    
    // MARK: - Lounge Management
    
    func createLounge(_ lounge: Lounge) {
        lounges.append(lounge)
        messages[lounge.id] = []
        saveLounges()
    }
    
    func joinLounge(_ lounge: Lounge, userId: String) {
        if let index = lounges.firstIndex(where: { $0.id == lounge.id }) {
            var updatedLounge = lounges[index]
            if !updatedLounge.members.contains(userId) {
                updatedLounge.members.append(userId)
                lounges[index] = updatedLounge
                saveLounges()
                
                // Log activity
                logActivity(LoungeActivity(
                    id: UUID(),
                    userId: userId,
                    userName: "User",
                    activityType: .joined,
                    timestamp: Date()
                ))
            }
        }
    }
    
    func leaveLounge(_ lounge: Lounge, userId: String) {
        if let index = lounges.firstIndex(where: { $0.id == lounge.id }) {
            var updatedLounge = lounges[index]
            updatedLounge.members.removeAll { $0 == userId }
            lounges[index] = updatedLounge
            saveLounges()
        }
    }
    
    func getLoungesForUser(userId: String) -> [Lounge] {
        lounges.filter { $0.members.contains(userId) || !$0.isPrivate }
    }
    
    // MARK: - Messaging
    
    func sendMessage(_ message: LoungeMessage) {
        if messages[message.loungeId] != nil {
            messages[message.loungeId]?.append(message)
        } else {
            messages[message.loungeId] = [message]
        }
        saveMessages(for: message.loungeId)
        
        // Update unread counts for other members
        updateUnreadCounts(for: message.loungeId)
    }
    
    func addReaction(to message: LoungeMessage, emoji: String, userId: String) {
        guard let loungeMessages = messages[message.loungeId],
              let messageIndex = loungeMessages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        
        var updatedMessage = loungeMessages[messageIndex]
        
        if let reactionIndex = updatedMessage.reactions.firstIndex(where: { $0.emoji == emoji }) {
            var reaction = updatedMessage.reactions[reactionIndex]
            if !reaction.userIds.contains(userId) {
                reaction.userIds.append(userId)
                updatedMessage.reactions[reactionIndex] = reaction
            }
        } else {
            let newReaction = LoungeMessage.Reaction(emoji: emoji, userIds: [userId])
            updatedMessage.reactions.append(newReaction)
        }
        
        messages[message.loungeId]?[messageIndex] = updatedMessage
        saveMessages(for: message.loungeId)
    }
    
    func replyToMessage(_ message: LoungeMessage, reply: LoungeMessage) {
        guard let loungeMessages = messages[message.loungeId],
              let messageIndex = loungeMessages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        
        var updatedMessage = loungeMessages[messageIndex]
        updatedMessage.threadReplies.append(reply)
        messages[message.loungeId]?[messageIndex] = updatedMessage
        saveMessages(for: message.loungeId)
    }
    
    func getMessages(for loungeId: UUID) -> [LoungeMessage] {
        messages[loungeId] ?? []
    }
    
    func markAsRead(loungeId: UUID) {
        unreadCounts[loungeId] = 0
    }
    
    private func updateUnreadCounts(for loungeId: UUID) {
        unreadCounts[loungeId, default: 0] += 1
    }
    
    // MARK: - Winddown Activities
    
    func startWinddownActivity(_ activity: WinddownActivity) {
        currentActivity = activity
    }
    
    func completeWinddownActivity(_ activity: WinddownActivity, userId: String) {
        if let index = winddownActivities.firstIndex(where: { $0.id == activity.id }) {
            winddownActivities[index].completionCount += 1
            saveWinddownActivities()
        }
        
        currentActivity = nil
        
        // Log completion
        logActivity(LoungeActivity(
            id: UUID(),
            userId: userId,
            userName: "User",
            activityType: .completedWinddown,
            timestamp: Date(),
            details: activity.title
        ))
        
        // Track well-being improvement
        WellBeingManager().currentMetrics.mindfulMinutes += activity.durationMinutes
    }
    
    func getPopularWinddownActivities() -> [WinddownActivity] {
        winddownActivities.sorted { $0.completionCount > $1.completionCount }.prefix(5).map { $0 }
    }
    
    func getRecommendedActivity(basedOnStress stressLevel: WellBeingMetrics.StressLevel) -> WinddownActivity? {
        switch stressLevel {
        case .low:
            return winddownActivities.first { $0.type == .gratitude }
        case .moderate:
            return winddownActivities.first { $0.type == .breathing }
        case .high:
            return winddownActivities.first { $0.type == .meditation }
        case .veryHigh:
            return winddownActivities.first { $0.type == .progressiveRelaxation }
        }
    }
    
    // MARK: - Setup Default Content
    
    private func setupDefaultLounges() {
        if lounges.isEmpty {
            // Create default lounges
            let generalLounge = Lounge(
                name: "General Chat",
                description: "Open space for general team communication",
                type: .general,
                loungeColor: .blue
            )
            
            let winddownLounge = Lounge(
                name: "Winddown Zone",
                description: "Relax, unwind, and recharge after work",
                type: .winddown,
                loungeColor: .purple
            )
            
            let celebrationLounge = Lounge(
                name: "Celebration Station",
                description: "Share wins, milestones, and celebrate together",
                type: .celebration,
                loungeColor: .orange
            )
            
            let wellnessLounge = Lounge(
                name: "Wellness Corner",
                description: "Share wellness tips and support each other's health",
                type: .wellness,
                loungeColor: .green
            )
            
            lounges = [generalLounge, winddownLounge, celebrationLounge, wellnessLounge]
            saveLounges()
        }
    }
    
    private func loadWinddownActivities() {
        if winddownActivities.isEmpty {
            winddownActivities = [
                WinddownActivity(
                    title: "Box Breathing",
                    description: "A simple 4-4-4-4 breathing pattern to reduce stress and increase calm",
                    type: .breathing,
                    durationMinutes: 5,
                    instructions: [
                        "Find a comfortable seated position",
                        "Breathe in through your nose for 4 counts",
                        "Hold your breath for 4 counts",
                        "Exhale through your mouth for 4 counts",
                        "Hold empty for 4 counts",
                        "Repeat for 5 minutes"
                    ]
                ),
                WinddownActivity(
                    title: "Gratitude Reflection",
                    description: "Take a moment to reflect on three things you're grateful for today",
                    type: .gratitude,
                    durationMinutes: 5,
                    instructions: [
                        "Find a quiet space",
                        "Think about your day",
                        "Identify three specific things you're grateful for",
                        "Consider why each matters to you",
                        "Optionally share one in the lounge"
                    ]
                ),
                WinddownActivity(
                    title: "Desk Stretches",
                    description: "Quick stretches to release tension from sitting",
                    type: .stretching,
                    durationMinutes: 10,
                    instructions: [
                        "Stand up from your desk",
                        "Neck rolls - 5 each direction",
                        "Shoulder shrugs - 10 repetitions",
                        "Arm circles - 10 each direction",
                        "Torso twists - 10 each side",
                        "Forward fold - hold 30 seconds",
                        "Side stretches - 30 seconds each side"
                    ]
                ),
                WinddownActivity(
                    title: "Guided Meditation",
                    description: "A peaceful 10-minute meditation to clear your mind",
                    type: .meditation,
                    durationMinutes: 10,
                    instructions: [
                        "Find a comfortable position",
                        "Close your eyes or soften your gaze",
                        "Focus on your natural breath",
                        "When thoughts arise, gently return to breath",
                        "Scan your body for tension",
                        "Release tension with each exhale",
                        "Slowly return your awareness to the room"
                    ]
                ),
                WinddownActivity(
                    title: "Progressive Muscle Relaxation",
                    description: "Systematically tense and relax muscle groups",
                    type: .progressiveRelaxation,
                    durationMinutes: 15,
                    instructions: [
                        "Lie down or sit comfortably",
                        "Tense feet for 5 seconds, then release",
                        "Tense calves for 5 seconds, then release",
                        "Continue up through: thighs, abdomen, chest, arms, hands, neck, face",
                        "Hold each tension for 5 seconds",
                        "Release and notice the relaxation",
                        "Breathe deeply throughout"
                    ]
                ),
                WinddownActivity(
                    title: "End of Day Reflection",
                    description: "Review your day and prepare for tomorrow",
                    type: .reflection,
                    durationMinutes: 10,
                    instructions: [
                        "Review what you accomplished today",
                        "Acknowledge one challenge you overcame",
                        "Identify one thing you learned",
                        "Think about what went well",
                        "Note one thing to improve tomorrow",
                        "Set an intention for tomorrow",
                        "Let go of today's stress"
                    ]
                )
            ]
            saveWinddownActivities()
        }
    }
    
    // MARK: - Persistence
    
    private func loadLounges() {
        // In a real app, load from Core Data or CloudKit
        lounges = []
    }
    
    private func saveLounges() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func saveMessages(for loungeId: UUID) {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func saveWinddownActivities() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func logActivity(_ activity: LoungeActivity) {
        // In a real app, log to analytics
    }
}
