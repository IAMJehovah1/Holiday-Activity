//
//  WorkflowOptimization.swift
//  WorkSOPro
//
//  AI-powered workflow optimization for maximum efficiency
//

import Foundation

struct WorkflowOptimization: Codable {
    var userId: UUID
    var analysisDate: Date
    var recommendations: [Recommendation]
    var efficiencyScore: Double // 0-100
    var potentialTimeSavings: Double // hours per week
    
    struct Recommendation: Codable, Identifiable {
        let id: UUID
        var title: String
        var description: String
        var category: Category
        var impact: Impact
        var implementationEffort: Effort
        var estimatedSavingsMinutes: Int
        var isImplemented: Bool
        
        enum Category: String, Codable {
            case taskPrioritization = "Task Prioritization"
            case meetingOptimization = "Meeting Optimization"
            case breakScheduling = "Break Scheduling"
            case focusTime = "Focus Time"
            case delegation = "Delegation"
            case automation = "Automation"
            case communication = "Communication"
            case wellBeing = "Well-Being"
        }
        
        enum Impact: String, Codable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
            
            var multiplier: Double {
                switch self {
                case .low: return 1.0
                case .medium: return 2.0
                case .high: return 3.0
                case .critical: return 5.0
                }
            }
        }
        
        enum Effort: String, Codable {
            case minimal = "Minimal"
            case moderate = "Moderate"
            case significant = "Significant"
        }
        
        init(
            id: UUID = UUID(),
            title: String,
            description: String,
            category: Category,
            impact: Impact,
            implementationEffort: Effort,
            estimatedSavingsMinutes: Int,
            isImplemented: Bool = false
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.category = category
            self.impact = impact
            self.implementationEffort = implementationEffort
            self.estimatedSavingsMinutes = estimatedSavingsMinutes
            self.isImplemented = isImplemented
        }
    }
    
    init(
        userId: UUID,
        analysisDate: Date = Date(),
        recommendations: [Recommendation] = [],
        efficiencyScore: Double = 0,
        potentialTimeSavings: Double = 0
    ) {
        self.userId = userId
        self.analysisDate = analysisDate
        self.recommendations = recommendations
        self.efficiencyScore = efficiencyScore
        self.potentialTimeSavings = potentialTimeSavings
    }
    
    mutating func generateRecommendations(basedOn history: UserProductivityHistory) {
        var newRecommendations: [Recommendation] = []
        
        // Analyze task completion patterns
        if history.averageTaskCompletionRate < 0.7 {
            newRecommendations.append(
                Recommendation(
                    title: "Improve Task Prioritization",
                    description: "Your task completion rate is \(Int(history.averageTaskCompletionRate * 100))%. Use AI-powered prioritization to focus on high-impact tasks first.",
                    category: .taskPrioritization,
                    impact: .high,
                    implementationEffort: .minimal,
                    estimatedSavingsMinutes: 120
                )
            )
        }
        
        // Analyze meeting efficiency
        if history.meetingHoursPerWeek > 15 {
            newRecommendations.append(
                Recommendation(
                    title: "Optimize Meeting Schedule",
                    description: "You spend \(Int(history.meetingHoursPerWeek)) hours/week in meetings. Consider declining non-essential meetings or reducing meeting duration.",
                    category: .meetingOptimization,
                    impact: .critical,
                    implementationEffort: .moderate,
                    estimatedSavingsMinutes: 180
                )
            )
        }
        
        // Analyze break patterns
        if history.averageBreaksPerDay < 4 {
            newRecommendations.append(
                Recommendation(
                    title: "Schedule Regular Breaks",
                    description: "Taking regular breaks improves focus and productivity. Schedule 5-minute breaks every 90 minutes.",
                    category: .breakScheduling,
                    impact: .medium,
                    implementationEffort: .minimal,
                    estimatedSavingsMinutes: 60
                )
            )
        }
        
        // Analyze focus time
        if history.deepWorkHoursPerWeek < 15 {
            newRecommendations.append(
                Recommendation(
                    title: "Block Focus Time",
                    description: "Protect at least 3 hours daily for deep work. Enable Do Not Disturb and batch similar tasks.",
                    category: .focusTime,
                    impact: .high,
                    implementationEffort: .moderate,
                    estimatedSavingsMinutes: 300
                )
            )
        }
        
        // Analyze well-being
        if history.averageWellBeingScore < 60 {
            newRecommendations.append(
                Recommendation(
                    title: "Prioritize Well-Being",
                    description: "Your well-being score is below optimal. This affects productivity. Take more breaks and ensure adequate sleep.",
                    category: .wellBeing,
                    impact: .critical,
                    implementationEffort: .moderate,
                    estimatedSavingsMinutes: 240
                )
            )
        }
        
        self.recommendations = newRecommendations
        self.potentialTimeSavings = Double(newRecommendations.reduce(0) { $0 + $1.estimatedSavingsMinutes }) / 60.0
        self.efficiencyScore = calculateEfficiencyScore(history: history)
    }
    
    private func calculateEfficiencyScore(history: UserProductivityHistory) -> Double {
        var score = 0.0
        
        // Task completion (30 points)
        score += history.averageTaskCompletionRate * 30
        
        // Meeting efficiency (20 points)
        let meetingScore = max(0, 20 - (history.meetingHoursPerWeek - 10) * 2)
        score += meetingScore
        
        // Focus time (20 points)
        score += min(20, history.deepWorkHoursPerWeek / 1.5)
        
        // Break balance (15 points)
        let breakScore = min(15, Double(history.averageBreaksPerDay) * 3)
        score += breakScore
        
        // Well-being (15 points)
        score += (history.averageWellBeingScore / 100) * 15
        
        return min(100, score)
    }
}

struct UserProductivityHistory: Codable {
    var userId: UUID
    var averageTaskCompletionRate: Double
    var meetingHoursPerWeek: Double
    var deepWorkHoursPerWeek: Double
    var averageBreaksPerDay: Int
    var averageWellBeingScore: Double
    var totalTasksCompleted: Int
    var averageProductiveHoursPerDay: Double
}
