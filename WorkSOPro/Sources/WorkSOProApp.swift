//
//  WorkSOProApp.swift
//  WorkSOPro
//
//  Created by Apple Inc.
//  Copyright © 2026 Apple Inc. All rights reserved.
//

import SwiftUI
import HealthKit

@main
struct WorkSOProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var taskManager = TaskManager()
    @StateObject private var wellBeingManager = WellBeingManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(taskManager)
                .environmentObject(wellBeingManager)
                .environmentObject(subscriptionManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Request HealthKit authorization
        wellBeingManager.requestHealthKitAuthorization()
        
        // Setup notifications
        NotificationManager.shared.requestAuthorization()
        
        // Initialize user session
        appState.initializeUserSession()
        
        // Check subscription status
        subscriptionManager.checkSubscriptionStatus()
    }
}
