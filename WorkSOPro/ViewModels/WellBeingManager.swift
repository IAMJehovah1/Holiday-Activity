//
//  WellBeingManager.swift
//  WorkSOPro
//
//  ViewModel for managing well-being and health tracking
//

import Foundation
import Combine
import HealthKit

class WellBeingManager: ObservableObject {
    @Published var currentMetrics: WellBeingMetrics
    @Published var weeklyMetrics: [WellBeingMetrics] = []
    @Published var isHealthKitAuthorized = false
    @Published var shouldShowBreakReminder = false
    @Published var lastBreakTime: Date?
    
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    private var breakTimer: Timer?
    private let workerPool = ThermalAwareWorkerPool(maxConcurrentTasks: 1)
    
    init() {
        self.currentMetrics = WellBeingMetrics()
        startBreakMonitoring()
        loadWeeklyMetrics()
    }
    
    // MARK: - HealthKit Integration
    
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isHealthKitAuthorized = success
                if success {
                    self?.syncHealthKitData()
                }
            }
        }
    }
    
    func syncHealthKitData() {
        guard isHealthKitAuthorized else { return }
        Task { [weak self] in
            guard let self = self else { return }

            await workerPool.executeTask(isHighImpactTask: true) { [weak self] in
                guard let self = self else { return }

                await self.fetchStepCount()
                await self.fetchExerciseTime()
                await self.fetchStandHours()
                await self.fetchMindfulMinutes()
                await self.fetchSleepData()
            }
        }
    }
    
    private func fetchStepCount() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
                let steps = result?.sumQuantity().map { Int($0.doubleValue(for: HKUnit.count())) } ?? 0

                Task { [weak self] in
                    await self?.setStepCount(steps)
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }
    
    private func fetchExerciseTime() async {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
                let minutes = result?.sumQuantity().map { Int($0.doubleValue(for: HKUnit.minute())) } ?? 0

                Task { [weak self] in
                    await self?.setExerciseMinutes(minutes)
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }
    
    private func fetchStandHours() async {
        guard let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: standType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
                let hours = result?.sumQuantity().map { Int($0.doubleValue(for: HKUnit.hour())) } ?? 0

                Task { [weak self] in
                    await self?.setStandHours(hours)
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }
    
    private func fetchMindfulMinutes() async {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                let mindfulSamples = samples as? [HKCategorySample] ?? []
                let totalMinutes = mindfulSamples.reduce(0) { total, sample in
                    total + Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
                }

                Task { [weak self] in
                    await self?.setMindfulMinutes(totalMinutes)
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                let sleepSamples = (samples as? [HKCategorySample] ?? []).filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                }
                let totalMinutes = sleepSamples.reduce(0.0) { total, sample in
                    total + (sample.endDate.timeIntervalSince(sample.startDate) / 60)
                }

                Task { [weak self] in
                    await self?.setSleepHours(totalMinutes / 60.0)
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }
    
    @MainActor
    private func setStepCount(_ steps: Int) {
        currentMetrics.stepsCount = steps
    }

    @MainActor
    private func setExerciseMinutes(_ minutes: Int) {
        currentMetrics.exerciseMinutes = minutes
    }

    @MainActor
    private func setStandHours(_ hours: Int) {
        currentMetrics.standHours = hours
    }

    @MainActor
    private func setMindfulMinutes(_ minutes: Int) {
        currentMetrics.mindfulMinutes = minutes
    }

    @MainActor
    private func setSleepHours(_ hours: Double) {
        currentMetrics.sleepHours = hours
    }

    // MARK: - Break Monitoring
    
    private func startBreakMonitoring() {
        breakTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBreakNeeded()
        }
    }
    
    private func checkBreakNeeded() {
        let minutesSinceLastBreak: Int
        if let lastBreak = lastBreakTime {
            minutesSinceLastBreak = Int(Date().timeIntervalSince(lastBreak) / 60)
        } else {
            minutesSinceLastBreak = 90
        }
        
        // Recommend break every 90 minutes
        if minutesSinceLastBreak >= 90 {
            shouldShowBreakReminder = true
            NotificationManager.shared.sendBreakReminder()
        }
    }
    
    func recordBreak() {
        lastBreakTime = Date()
        shouldShowBreakReminder = false
        currentMetrics.breaksCount += 1
        saveMetrics()
    }
    
    func updateStressLevel(_ level: WellBeingMetrics.StressLevel) {
        currentMetrics.stressLevel = level
        saveMetrics()
    }
    
    func recordHydration() {
        currentMetrics.hydrationGlasses += 1
        saveMetrics()
    }
    
    func recordScreenTime(minutes: Int) {
        currentMetrics.screenTimeMinutes += minutes
        saveMetrics()
    }
    
    // MARK: - Persistence
    
    private func loadWeeklyMetrics() {
        // In a real app, load from Core Data or CloudKit
        weeklyMetrics = []
    }
    
    private func saveMetrics() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
}
