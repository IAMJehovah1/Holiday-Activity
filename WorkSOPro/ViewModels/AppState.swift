//
//  AppState.swift
//  WorkSOPro
//
//  Central app state management
//

import Foundation
import Combine

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var selectedTab: Tab = .dashboard
    @Published var showOnboarding = true
    
    enum Tab {
        case dashboard
        case tasks
        case lounge
        case projects
        case wellBeing
        case analytics
        case settings
    }
    
    init() {
        initializeUserSession()
    }
    
    func initializeUserSession() {
        // In a real app, check for existing auth token
        // For now, create a demo user
        currentUser = User(
            id: UUID(),
            email: "user@apple.com",
            name: "Demo User",
            organization: "Apple Inc."
        )
        isAuthenticated = currentUser != nil
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    var email: String
    var name: String
    var organization: String?
    var role: UserRole = .individual
    var avatarURL: URL?
    var createdAt: Date = Date()
    
    enum UserRole: String, Codable {
        case individual = "Individual"
        case teamMember = "Team Member"
        case teamAdmin = "Team Admin"
        case enterpriseAdmin = "Enterprise Admin"
    }
}
