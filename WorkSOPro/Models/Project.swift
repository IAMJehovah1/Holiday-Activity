//
//  Project.swift
//  WorkSOPro
//
//  Model representing a project containing multiple tasks
//

import Foundation
import SwiftUI

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var color: ProjectColor
    var createdAt: Date
    var isShared: Bool
    var teamMembers: [String] // User IDs
    var goal: String?
    
    enum ProjectColor: String, Codable, CaseIterable {
        case blue = "Blue"
        case green = "Green"
        case orange = "Orange"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case teal = "Teal"
        case indigo = "Indigo"
        
        var color: Color {
            switch self {
            case .blue: return .blue
            case .green: return .green
            case .orange: return .orange
            case .purple: return .purple
            case .pink: return .pink
            case .red: return .red
            case .teal: return .teal
            case .indigo: return .indigo
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        color: ProjectColor = .blue,
        isShared: Bool = false,
        teamMembers: [String] = [],
        goal: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.color = color
        self.createdAt = Date()
        self.isShared = isShared
        self.teamMembers = teamMembers
        self.goal = goal
    }
}
