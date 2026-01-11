//
//  ProfitMetrics.swift
//  WorkSOPro
//
//  Model for tracking profit impact and ROI
//

import Foundation

struct ProfitMetrics: Codable {
    var organizationId: UUID
    var periodStart: Date
    var periodEnd: Date
    
    // Productivity metrics
    var tasksCompleted: Int
    var totalProductiveHours: Double
    var averageTaskCompletionTime: Double
    var meetingEfficiencyScore: Double
    
    // Time savings
    var timeWastedReduced: Double // hours
    var meetingTimeOptimized: Double // hours
    var focusTimeGained: Double // hours
    
    // Cost savings
    var estimatedSalaryCostPerHour: Decimal
    var totalTimeSavingsValue: Decimal
    var reducedOvertimeCost: Decimal
    var reducedTurnoverCost: Decimal
    
    // Well-being impact
    var averageWellBeingScore: Double
    var employeeEngagementScore: Double
    var burnoutRiskReduction: Double
    var absenteeismReduction: Double
    
    // Revenue impact
    var productivityIncrease: Double // percentage
    var estimatedRevenueIncrease: Decimal
    var customerSatisfactionImprovement: Double
    
    init(
        organizationId: UUID,
        periodStart: Date,
        periodEnd: Date,
        tasksCompleted: Int = 0,
        totalProductiveHours: Double = 0,
        averageTaskCompletionTime: Double = 0,
        meetingEfficiencyScore: Double = 0,
        timeWastedReduced: Double = 0,
        meetingTimeOptimized: Double = 0,
        focusTimeGained: Double = 0,
        estimatedSalaryCostPerHour: Decimal = 50,
        averageWellBeingScore: Double = 0,
        employeeEngagementScore: Double = 0,
        burnoutRiskReduction: Double = 0,
        absenteeismReduction: Double = 0,
        productivityIncrease: Double = 0,
        estimatedRevenueIncrease: Decimal = 0,
        customerSatisfactionImprovement: Double = 0
    ) {
        self.organizationId = organizationId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.tasksCompleted = tasksCompleted
        self.totalProductiveHours = totalProductiveHours
        self.averageTaskCompletionTime = averageTaskCompletionTime
        self.meetingEfficiencyScore = meetingEfficiencyScore
        self.timeWastedReduced = timeWastedReduced
        self.meetingTimeOptimized = meetingTimeOptimized
        self.focusTimeGained = focusTimeGained
        self.estimatedSalaryCostPerHour = estimatedSalaryCostPerHour
        self.totalTimeSavingsValue = 0
        self.reducedOvertimeCost = 0
        self.reducedTurnoverCost = 0
        self.averageWellBeingScore = averageWellBeingScore
        self.employeeEngagementScore = employeeEngagementScore
        self.burnoutRiskReduction = burnoutRiskReduction
        self.absenteeismReduction = absenteeismReduction
        self.productivityIncrease = productivityIncrease
        self.estimatedRevenueIncrease = estimatedRevenueIncrease
        self.customerSatisfactionImprovement = customerSatisfactionImprovement
    }
    
    mutating func calculateTotalROI() -> Decimal {
        // Calculate total time savings value
        let totalHoursSaved = timeWastedReduced + meetingTimeOptimized + focusTimeGained
        totalTimeSavingsValue = Decimal(totalHoursSaved) * estimatedSalaryCostPerHour
        
        // Estimate reduced overtime (productivity increase means less overtime)
        reducedOvertimeCost = totalTimeSavingsValue * Decimal(0.15)
        
        // Estimate reduced turnover (better well-being = lower turnover)
        let turnoverReductionRate = burnoutRiskReduction / 100.0
        reducedTurnoverCost = estimatedSalaryCostPerHour * Decimal(turnoverReductionRate * 2000) // Annual impact
        
        // Total ROI
        let totalSavings = totalTimeSavingsValue + reducedOvertimeCost + reducedTurnoverCost
        let totalGains = estimatedRevenueIncrease
        
        return totalSavings + totalGains
    }
    
    var roiMultiplier: Double {
        let roi = calculateTotalROI()
        let subscriptionCost = Decimal(1000) // Estimated monthly cost
        guard subscriptionCost > 0 else { return 0 }
        return Double(truncating: (roi / subscriptionCost) as NSNumber)
    }
    
    var profitSummary: String {
        let roi = calculateTotalROI()
        let roiFormatted = formatCurrency(roi)
        
        return """
        Total ROI: \(roiFormatted)
        Time Savings: \(formatCurrency(totalTimeSavingsValue))
        Revenue Increase: \(formatCurrency(estimatedRevenueIncrease))
        Cost Reduction: \(formatCurrency(reducedOvertimeCost + reducedTurnoverCost))
        ROI Multiplier: \(String(format: "%.1fx", roiMultiplier))
        """
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSNumber) ?? "$0"
    }
}
