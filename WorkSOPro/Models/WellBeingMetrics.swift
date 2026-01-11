//
//  WellBeingMetrics.swift
//  WorkSOPro
//
//  Model for tracking well-being and health metrics
//

import Foundation
import SwiftUI

struct WellBeingMetrics: Codable {
    var date: Date
    var screenTimeMinutes: Int
    var breaksCount: Int
    var stepsCount: Int
    var standHours: Int
    var exerciseMinutes: Int
    var mindfulMinutes: Int
    var stressLevel: StressLevel
    var sleepHours: Double?
    var hydrationGlasses: Int
    
    enum StressLevel: String, Codable, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .veryHigh: return .red
            }
        }
        
        var emoji: String {
            switch self {
            case .low: return "😌"
            case .moderate: return "😐"
            case .high: return "😰"
            case .veryHigh: return "😫"
            }
        }
    }
    
    init(
        date: Date = Date(),
        screenTimeMinutes: Int = 0,
        breaksCount: Int = 0,
        stepsCount: Int = 0,
        standHours: Int = 0,
        exerciseMinutes: Int = 0,
        mindfulMinutes: Int = 0,
        stressLevel: StressLevel = .moderate,
        sleepHours: Double? = nil,
        hydrationGlasses: Int = 0
    ) {
        self.date = date
        self.screenTimeMinutes = screenTimeMinutes
        self.breaksCount = breaksCount
        self.stepsCount = stepsCount
        self.standHours = standHours
        self.exerciseMinutes = exerciseMinutes
        self.mindfulMinutes = mindfulMinutes
        self.stressLevel = stressLevel
        self.sleepHours = sleepHours
        self.hydrationGlasses = hydrationGlasses
    }
    
    var wellBeingScore: Int {
        var score = 0
        
        // Screen time (max 20 points)
        score += max(0, 20 - (screenTimeMinutes / 30))
        
        // Breaks (max 20 points)
        score += min(20, breaksCount * 3)
        
        // Physical activity (max 20 points)
        score += min(20, (stepsCount / 500) + (exerciseMinutes / 3))
        
        // Mindfulness (max 15 points)
        score += min(15, mindfulMinutes)
        
        // Sleep (max 15 points)
        if let sleep = sleepHours {
            let optimal = abs(sleep - 8.0)
            score += max(0, 15 - Int(optimal * 3))
        }
        
        // Hydration (max 10 points)
        score += min(10, hydrationGlasses)
        
        return min(100, score)
    }
}
