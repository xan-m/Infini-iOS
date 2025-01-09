//
//  StepCountManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/7/24.
//

import CoreData

class StepCountManager: ObservableObject {
    static let shared = StepCountManager()
    
    let chartManager = ChartManager.shared
    
    func setStepCount(steps: Int32, isArbitrary: Bool, for date: Date) {
        let existingCounts = chartManager.stepPoints()
        
        if let existingCount = existingCounts.first(where: { Calendar.current.isDate($0.timestamp!, inSameDayAs: date) }) {
            updateStepCount(existingCount, with: steps, isArbitrary: isArbitrary, for: date)
        } else {
            chartManager.addStepDataPoint(steps: steps, time: date)
        }
    }
    
    private func updateStepCount(_ stepCount: StepCounts, with steps: Int32, isArbitrary: Bool, for date: Date) {
        if isArbitrary {
            stepCount.steps += steps
        } else {
            clearCurrentDaySteps()
            stepCount.steps = max(stepCount.steps, steps)
        }
        
        stepCount.timestamp = date
        saveContext()
    }
    
    func clearCurrentDaySteps() {
        let today = Date()
        let existingCounts = chartManager.stepPoints()
        
        if let currentDayCount = existingCounts.first(where: { Calendar.current.isDate($0.timestamp!, inSameDayAs: today) }) {
            currentDayCount.steps = 0
            currentDayCount.timestamp = today
        } else {
            chartManager.addStepDataPoint(steps: 0, time: today)
        }
        
        saveContext()
    }
    
    private func saveContext() {
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            log(error.localizedDescription, caller: "StepCountManager")
        }
    }
}
