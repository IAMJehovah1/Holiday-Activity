//
//  RevenueTracker.swift
//  WorkSOPro
//
//  Service for tracking revenue and profit metrics
//

import Foundation

class RevenueTracker {
    static let shared = RevenueTracker()
    
    private var subscriptionEvents: [SubscriptionEvent] = []
    private var revenueMetrics: [RevenueMetrics] = []
    
    private init() {}
    
    struct SubscriptionEvent: Codable {
        let timestamp: Date
        let eventType: EventType
        let tier: SubscriptionTier
        let billingCycle: Subscription.BillingCycle
        let amount: Decimal
        let userId: UUID
        
        enum EventType: String, Codable {
            case subscribed
            case upgraded
            case downgraded
            case cancelled
            case renewed
            case refunded
        }
    }
    
    struct RevenueMetrics: Codable {
        let period: DateInterval
        var totalRevenue: Decimal
        var recurringRevenue: Decimal
        var newSubscriptions: Int
        var upgrades: Int
        var cancellations: Int
        var churnRate: Double
        var averageRevenuePerUser: Decimal
        var lifetimeValue: Decimal
        
        var monthlyRecurringRevenue: Decimal {
            recurringRevenue
        }
        
        var annualRecurringRevenue: Decimal {
            recurringRevenue * 12
        }
    }
    
    // MARK: - Revenue Tracking
    
    func recordSubscription(tier: SubscriptionTier, cycle: Subscription.BillingCycle, userId: UUID = UUID()) {
        let amount = cycle == .monthly ? tier.monthlyPrice : tier.yearlyPrice
        
        let event = SubscriptionEvent(
            timestamp: Date(),
            eventType: .subscribed,
            tier: tier,
            billingCycle: cycle,
            amount: amount,
            userId: userId
        )
        
        subscriptionEvents.append(event)
        updateRevenueMetrics()
    }
    
    func recordUpgrade(from: SubscriptionTier, to: SubscriptionTier, cycle: Subscription.BillingCycle, userId: UUID) {
        let amount = cycle == .monthly ? to.monthlyPrice : to.yearlyPrice
        
        let event = SubscriptionEvent(
            timestamp: Date(),
            eventType: .upgraded,
            tier: to,
            billingCycle: cycle,
            amount: amount,
            userId: userId
        )
        
        subscriptionEvents.append(event)
        updateRevenueMetrics()
    }
    
    func recordCancellation(tier: SubscriptionTier, userId: UUID) {
        let event = SubscriptionEvent(
            timestamp: Date(),
            eventType: .cancelled,
            tier: tier,
            billingCycle: .monthly,
            amount: 0,
            userId: userId
        )
        
        subscriptionEvents.append(event)
        updateRevenueMetrics()
    }
    
    // MARK: - Analytics
    
    func getMonthlyRevenueReport() -> RevenueMetrics? {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return getRevenueMetrics(for: DateInterval(start: startOfMonth, end: endOfMonth))
    }
    
    func getRevenueMetrics(for period: DateInterval) -> RevenueMetrics {
        let events = subscriptionEvents.filter { event in
            event.timestamp >= period.start && event.timestamp <= period.end
        }
        
        let totalRevenue = events
            .filter { $0.eventType == .subscribed || $0.eventType == .upgraded || $0.eventType == .renewed }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        let activeSubscriptions = events.filter { $0.eventType == .subscribed || $0.eventType == .upgraded }
        let recurringRevenue = activeSubscriptions
            .reduce(Decimal(0)) { total, event in
                let monthlyAmount = event.billingCycle == .monthly ? event.amount : event.amount / 12
                return total + monthlyAmount
            }
        
        let newSubs = events.filter { $0.eventType == .subscribed }.count
        let upgrades = events.filter { $0.eventType == .upgraded }.count
        let cancellations = events.filter { $0.eventType == .cancelled }.count
        
        let totalUsers = Set(events.map { $0.userId }).count
        let churnRate = totalUsers > 0 ? Double(cancellations) / Double(totalUsers) : 0.0
        
        let arpu = totalUsers > 0 ? totalRevenue / Decimal(totalUsers) : 0
        let ltv = arpu * Decimal(36) // 3-year average lifetime
        
        return RevenueMetrics(
            period: period,
            totalRevenue: totalRevenue,
            recurringRevenue: recurringRevenue,
            newSubscriptions: newSubs,
            upgrades: upgrades,
            cancellations: cancellations,
            churnRate: churnRate,
            averageRevenuePerUser: arpu,
            lifetimeValue: ltv
        )
    }
    
    func calculateProfitMargin() -> Double {
        // Simplified profit calculation
        guard let metrics = getMonthlyRevenueReport() else { return 0 }
        
        let revenue = Double(truncating: metrics.totalRevenue as NSNumber)
        let estimatedCosts = revenue * 0.30 // 30% costs (hosting, support, etc.)
        let profit = revenue - estimatedCosts
        
        return (profit / revenue) * 100 // Profit margin percentage
    }
    
    func projectedAnnualRevenue() -> Decimal {
        guard let monthlyMetrics = getMonthlyRevenueReport() else { return 0 }
        return monthlyMetrics.monthlyRecurringRevenue * 12
    }
    
    private func updateRevenueMetrics() {
        // In a real app, update analytics dashboard
        objectWillChange()
    }
    
    private func objectWillChange() {
        // Placeholder for notification
    }
}
