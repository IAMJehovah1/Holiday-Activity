//
//  Lounge.swift
//  WorkSOPro
//
//  Model for employee lounge - communication and winddown space
//

import Foundation
import SwiftUI

struct Lounge: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var type: LoungeType
    var members: [String] // User IDs
    var createdAt: Date
    var isPrivate: Bool
    var loungeColor: LoungeColor
    
    enum LoungeType: String, Codable, CaseIterable {
        case general = "General"
        case winddown = "Winddown"
        case social = "Social"
        case wellness = "Wellness"
        case celebration = "Celebration"
        case support = "Support"
        
        var icon: String {
            switch self {
            case .general: return "bubble.left.and.bubble.right.fill"
            case .winddown: return "moon.stars.fill"
            case .social: return "person.3.fill"
            case .wellness: return "heart.circle.fill"
            case .celebration: return "party.popper.fill"
            case .support: return "hands.and.sparkles.fill"
            }
        }
        
        var suggestedActivities: [String] {
            switch self {
            case .general:
                return ["Team Updates", "Quick Chat", "Announcements", "Water Cooler Talk"]
            case .winddown:
                return ["Meditation", "Breathing Exercises", "Quiet Time", "Reflection", "Gratitude Sharing"]
            case .social:
                return ["Virtual Coffee", "Hobby Sharing", "Fun Polls", "Game Time", "Photo Sharing"]
            case .wellness:
                return ["Wellness Tips", "Fitness Challenges", "Mental Health Check-ins", "Healthy Recipes"]
            case .celebration:
                return ["Achievements", "Birthdays", "Work Anniversaries", "Milestones", "Kudos"]
            case .support:
                return ["Peer Support", "Mentorship", "Problem Solving", "Encouragement"]
            }
        }
    }
    
    enum LoungeColor: String, Codable, CaseIterable {
        case blue, green, purple, orange, pink, teal, indigo, mint
        
        var color: Color {
            switch self {
            case .blue: return .blue
            case .green: return .green
            case .purple: return .purple
            case .orange: return .orange
            case .pink: return .pink
            case .teal: return .teal
            case .indigo: return .indigo
            case .mint: return .mint
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: LoungeType,
        members: [String] = [],
        isPrivate: Bool = false,
        loungeColor: LoungeColor = .blue
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.members = members
        self.createdAt = Date()
        self.isPrivate = isPrivate
        self.loungeColor = loungeColor
    }
}

struct LoungeMessage: Identifiable, Codable {
    let id: UUID
    var loungeId: UUID
    var authorId: String
    var authorName: String
    var content: String
    var timestamp: Date
    var reactions: [Reaction]
    var threadReplies: [LoungeMessage]
    var messageType: MessageType
    var attachments: [Attachment]?
    
    enum MessageType: String, Codable {
        case text = "Text"
        case poll = "Poll"
        case announcement = "Announcement"
        case winddownActivity = "Winddown Activity"
        case celebration = "Celebration"
        case gratitude = "Gratitude"
        case meditation = "Meditation"
    }
    
    struct Reaction: Codable, Identifiable {
        let id: UUID
        var emoji: String
        var userIds: [String]
        
        init(id: UUID = UUID(), emoji: String, userIds: [String] = []) {
            self.id = id
            self.emoji = emoji
            self.userIds = userIds
        }
    }
    
    struct Attachment: Codable, Identifiable {
        let id: UUID
        var url: URL
        var type: AttachmentType
        var thumbnailURL: URL?
        
        enum AttachmentType: String, Codable {
            case image, video, audio, document
        }
    }
    
    init(
        id: UUID = UUID(),
        loungeId: UUID,
        authorId: String,
        authorName: String,
        content: String,
        timestamp: Date = Date(),
        reactions: [Reaction] = [],
        threadReplies: [LoungeMessage] = [],
        messageType: MessageType = .text,
        attachments: [Attachment]? = nil
    ) {
        self.id = id
        self.loungeId = loungeId
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.timestamp = timestamp
        self.reactions = reactions
        self.threadReplies = threadReplies
        self.messageType = messageType
        self.attachments = attachments
    }
}

struct WinddownActivity: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var type: ActivityType
    var durationMinutes: Int
    var instructions: [String]
    var audioGuideURL: URL?
    var completionCount: Int
    
    enum ActivityType: String, Codable, CaseIterable {
        case breathing = "Breathing Exercise"
        case meditation = "Meditation"
        case stretching = "Stretching"
        case reflection = "Reflection"
        case gratitude = "Gratitude Practice"
        case visualization = "Visualization"
        case progressiveRelaxation = "Progressive Relaxation"
        
        var icon: String {
            switch self {
            case .breathing: return "wind"
            case .meditation: return "moon.stars"
            case .stretching: return "figure.walk"
            case .reflection: return "book.closed"
            case .gratitude: return "heart.text.square"
            case .visualization: return "eye"
            case .progressiveRelaxation: return "bed.double"
            }
        }
        
        var color: Color {
            switch self {
            case .breathing: return .cyan
            case .meditation: return .purple
            case .stretching: return .green
            case .reflection: return .orange
            case .gratitude: return .pink
            case .visualization: return .blue
            case .progressiveRelaxation: return .indigo
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        type: ActivityType,
        durationMinutes: Int,
        instructions: [String],
        audioGuideURL: URL? = nil,
        completionCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.durationMinutes = durationMinutes
        self.instructions = instructions
        self.audioGuideURL = audioGuideURL
        self.completionCount = completionCount
    }
}

struct LoungeActivity: Identifiable, Codable {
    let id: UUID
    var userId: String
    var userName: String
    var activityType: ActivityType
    var timestamp: Date
    var details: String?
    
    enum ActivityType: String, Codable {
        case joined = "Joined"
        case posted = "Posted"
        case reacted = "Reacted"
        case completedWinddown = "Completed Winddown"
        case sharedGratitude = "Shared Gratitude"
        case celebrated = "Celebrated"
    }
}
