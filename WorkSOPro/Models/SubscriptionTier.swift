//
//  SubscriptionTier.swift
//  WorkSOPro
//
//  Model for subscription tiers and profit generation
//

import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "Free"
    case professional = "Professional"
    case team = "Team"
    case enterprise = "Enterprise"
    
    var displayName: String {
        rawValue
    }
    
    var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .professional: return 9.99
        case .team: return 24.99
        case .enterprise: return 0 // Custom pricing
        }
    }
    
    var yearlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .professional: return 99.99 // 2 months free
        case .team: return 249.99 // 2 months free per user
        case .enterprise: return 0 // Custom pricing
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Up to 20 tasks",
                "Basic task management",
                "Standard break reminders",
                "7-day analytics history",
                "Single project support",
                "Basic well-being tracking"
            ]
        case .professional:
            return [
                "Unlimited tasks and projects",
                "AI-powered task prioritization",
                "Advanced focus sessions",
                "Full well-being monitoring suite",
                "90-day analytics history",
                "Apple Watch integration",
                "Calendar integration",
                "HealthKit integration",
                "Priority email support",
                "Custom productivity reports"
            ]
        case .team:
            return [
                "All Professional features",
                "Team collaboration tools",
                "Shared projects and workspaces",
                "Team analytics dashboard",
                "Admin controls and permissions",
                "API access for integrations",
                "Workflow optimization insights",
                "Profit impact analysis",
                "Resource allocation tracking",
                "Dedicated account manager",
                "Unlimited analytics history",
                "Custom integration support",
                "Team well-being metrics"
            ]
        case .enterprise:
            return [
                "All Team features",
                "Custom integrations",
                "On-premise deployment options",
                "Advanced security features",
                "SSO/SAML authentication",
                "Custom training and onboarding",
                "SLA guarantees (99.9% uptime)",
                "White-label options",
                "Dedicated success manager",
                "24/7 priority support",
                "Custom analytics and reporting",
                "ROI guarantee programs",
                "Compliance certifications"
            ]
        }
    }
    
    var maxTasksPerProject: Int? {
        switch self {
        case .free: return 20
        case .professional, .team, .enterprise: return nil
        }
    }
    
    var maxProjects: Int? {
        switch self {
        case .free: return 1
        case .professional, .team, .enterprise: return nil
        }
    }
    
    var hasAIPrioritization: Bool {
        self != .free
    }
    
    var hasTeamCollaboration: Bool {
        self == .team || self == .enterprise
    }
    
    var hasAPIAccess: Bool {
        self == .team || self == .enterprise
    }
    
    var hasProfitAnalytics: Bool {
        self == .team || self == .enterprise
    }
    
    var analyticsHistoryDays: Int {
        switch self {
        case .free: return 7
        case .professional: return 90
        case .team, .enterprise: return 365 * 10 // Unlimited (10 years)
        }
    }
}

struct Subscription: Codable, Identifiable {
    let id: UUID
    var tier: SubscriptionTier
    var billingCycle: BillingCycle
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var autoRenew: Bool
    var teamSize: Int? // For team/enterprise
    var customFeatures: [String]? // For enterprise
    
    enum BillingCycle: String, Codable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        case custom = "Custom"
    }
    
    init(
        id: UUID = UUID(),
        tier: SubscriptionTier,
        billingCycle: BillingCycle = .monthly,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isActive: Bool = true,
        autoRenew: Bool = true,
        teamSize: Int? = nil,
        customFeatures: [String]? = nil
    ) {
        self.id = id
        self.tier = tier
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.autoRenew = autoRenew
        self.teamSize = teamSize
        self.customFeatures = customFeatures
    }
    
    var currentPrice: Decimal {
        switch billingCycle {
        case .monthly:
            if let teamSize = teamSize {
                return tier.monthlyPrice * Decimal(teamSize)
            }
            return tier.monthlyPrice
        case .yearly:
            if let teamSize = teamSize {
                return tier.yearlyPrice * Decimal(teamSize)
            }
            return tier.yearlyPrice
        case .custom:
            return 0 // Handled by sales team
        }
    }
    
    var isExpired: Bool {
        guard let endDate = endDate else { return false }
        return endDate < Date()
    }
}
