//
//  ThermalAwareWorkerPool.swift
//  WorkSOPro
//
//  Limits concurrent high-impact work to reduce sustained thermal pressure.
//

import Foundation

actor ThermalAwareWorkerPool {
    private enum ThermalState {
        case nominal
        case fair
        case serious
        case critical
    }
    
    private let maxConcurrentTasks: Int
    private var activeTasksCount = 0
    
    init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }
    
    func executeTask(isHighImpactTask: Bool = false, _ task: @escaping () async -> Void) async {
        while shouldThrottleNewTask(isHighImpactTask: isHighImpactTask) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        if let cooldown = preExecutionCooldown(isHighImpactTask: isHighImpactTask) {
            try? await Task.sleep(for: cooldown)
        }
        
        activeTasksCount += 1
        
        let taskPriority = priority(isHighImpactTask: isHighImpactTask)
        let completionCooldown = postExecutionCooldown(isHighImpactTask: isHighImpactTask)
        
        Task.detached(priority: taskPriority) { [self] in
            await task()
            
            if let cooldown = completionCooldown {
                try? await Task.sleep(for: cooldown)
            }

            await self.taskCompleted()
        }
    }
    
    private func taskCompleted() {
        activeTasksCount -= 1
    }
    
    private func shouldThrottleNewTask(isHighImpactTask: Bool) -> Bool {
        let thermalState = currentThermalState()
        
        if isHighImpactTask && thermalState == .critical {
            return true
        }
        
        return activeTasksCount >= maxAllowedConcurrentTasks(for: thermalState)
    }
    
    private func maxAllowedConcurrentTasks(for thermalState: ThermalState) -> Int {
        switch thermalState {
        case .nominal:
            return maxConcurrentTasks
        case .fair:
            return max(1, maxConcurrentTasks - 1)
        case .serious, .critical:
            return 1
        }
    }
    
    private func priority(isHighImpactTask: Bool) -> TaskPriority {
        switch currentThermalState() {
        case .nominal:
            return isHighImpactTask ? .utility : .medium
        case .fair:
            return .utility
        case .serious, .critical:
            return .background
        }
    }
    
    private func preExecutionCooldown(isHighImpactTask: Bool) -> Duration? {
        guard isHighImpactTask else { return nil }
        
        switch currentThermalState() {
        case .nominal:
            return nil
        case .fair:
            return .milliseconds(150)
        case .serious:
            return .milliseconds(500)
        case .critical:
            return .seconds(1)
        }
    }
    
    private func postExecutionCooldown(isHighImpactTask: Bool) -> Duration? {
        guard isHighImpactTask else { return nil }
        
        switch currentThermalState() {
        case .nominal:
            return .milliseconds(100)
        case .fair:
            return .milliseconds(250)
        case .serious, .critical:
            return .milliseconds(750)
        }
    }
    
    private func currentThermalState() -> ThermalState {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .serious
        }
        #else
        return .nominal
        #endif
    }
}
