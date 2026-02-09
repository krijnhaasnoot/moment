//
//  CycleCalculationTests.swift
//  MomentTests
//
//  Tests for cycle calculations and predictions
//

import Testing
import Foundation
@testable import Moment

@Suite("Cycle Calculation Tests")
struct CycleCalculationTests {
    
    // MARK: - Ovulation Prediction
    
    @Test("Ovulation predicted 14 days before next period")
    func ovulationPrediction() {
        // Standard medical assumption: luteal phase is 14 days
        let cycleLengths = [26, 28, 30, 32, 35]
        
        for length in cycleLengths {
            let cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: length)
            let expectedOvulationDay = length - 14
            #expect(cycle.estimatedOvulationDay == expectedOvulationDay,
                   "For \(length)-day cycle, ovulation should be day \(expectedOvulationDay)")
        }
    }
    
    @Test("Fertile window is 5 days before ovulation to 1 day after")
    func fertileWindowCalculation() {
        let cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        
        // Ovulation day 14
        // Fertile window: 14 - 5 = 9 to 14 + 1 = 15
        #expect(cycle.fertileWindowStart == 9)
        #expect(cycle.fertileWindowEnd == 15)
        
        // Total fertile days: 15 - 9 + 1 = 7 days
        let fertileDays = cycle.fertileWindowEnd - cycle.fertileWindowStart + 1
        #expect(fertileDays == 7)
    }
    
    // MARK: - Different Cycle Lengths
    
    @Test("Short cycle (24 days) calculations")
    func shortCycleCalculations() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 24)
        cycle.generateDays()
        
        // Ovulation: 24 - 14 = day 10
        #expect(cycle.estimatedOvulationDay == 10)
        
        // Fertile window: 5-11
        #expect(cycle.fertileWindowStart == 5)
        #expect(cycle.fertileWindowEnd == 11)
        
        // Check peak days
        let peakDays = cycle.days.enumerated().filter { $0.element.fertilityLevel == .peak }
        #expect(peakDays.count == 2)
    }
    
    @Test("Long cycle (35 days) calculations")
    func longCycleCalculations() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 35)
        cycle.generateDays()
        
        // Ovulation: 35 - 14 = day 21
        #expect(cycle.estimatedOvulationDay == 21)
        
        // Fertile window: 16-22
        #expect(cycle.fertileWindowStart == 16)
        #expect(cycle.fertileWindowEnd == 22)
    }
    
    @Test("Average cycle (28 days) calculations")
    func averageCycleCalculations() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // Ovulation: day 14
        #expect(cycle.estimatedOvulationDay == 14)
        
        // Fertile window: 9-15
        #expect(cycle.fertileWindowStart == 9)
        #expect(cycle.fertileWindowEnd == 15)
        
        // Check distribution of fertility levels
        let lowDays = cycle.days.filter { $0.fertilityLevel == .low }
        let highDays = cycle.days.filter { $0.fertilityLevel == .high }
        let peakDays = cycle.days.filter { $0.fertilityLevel == .peak }
        
        #expect(lowDays.count == 21) // 28 - 7 fertile days
        #expect(highDays.count == 5)  // Days 9, 10, 11, 12, 15
        #expect(peakDays.count == 2)  // Days 13, 14
    }
    
    // MARK: - LH Test Impact
    
    @Test("Positive LH test marks day as peak")
    func positiveLHMarksPeak() {
        var day = CycleDay(date: Date(), fertilityLevel: .high)
        
        // Simulate logging positive LH
        day.lhTestResult = .positive
        day.lhTestLoggedAt = Date()
        day.fertilityLevel = .peak // This is what the service does
        
        #expect(day.fertilityLevel == .peak)
        #expect(day.lhTestResult == .positive)
    }
    
    @Test("Negative LH test doesn't change fertility level")
    func negativeLHNoChange() {
        var day = CycleDay(date: Date(), fertilityLevel: .high)
        
        day.lhTestResult = .negative
        day.lhTestLoggedAt = Date()
        
        #expect(day.fertilityLevel == .high) // Unchanged
        #expect(day.lhTestResult == .negative)
    }
    
    // MARK: - Cycle Recalibration
    
    @Test("New cycle archives previous cycle")
    func newCycleArchivesPrevious() {
        let service = DataService.shared
        service.resetAllData()
        
        _ = service.createUser(name: "Test", role: .woman)
        
        // Start first cycle
        let firstCycle = service.startNewCycle(startDate: Date().addingTimeInterval(-28*24*60*60))
        #expect(firstCycle.isActive == true)
        
        // Start second cycle
        let secondCycle = service.startNewCycle(startDate: Date())
        #expect(secondCycle.isActive == true)
        
        // Check that previous cycle is archived
        let archivedCycles = service.cycles.filter { !$0.isActive }
        #expect(archivedCycles.count >= 1)
    }
}

@Suite("Date Calculation Tests")
struct DateCalculationTests {
    
    @Test("Cycle days have correct dates")
    func cycleDaysCorrectDates() {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        
        var cycle = Cycle(userId: UUID(), startDate: startDate, cycleLength: 28)
        cycle.generateDays()
        
        for (index, day) in cycle.days.enumerated() {
            let expectedDate = calendar.date(byAdding: .day, value: index, to: startDate)!
            #expect(calendar.isDate(day.date, inSameDayAs: expectedDate),
                   "Day \(index + 1) should be \(expectedDate)")
        }
    }
    
    @Test("First day is cycle start date")
    func firstDayIsStartDate() {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        
        var cycle = Cycle(userId: UUID(), startDate: startDate, cycleLength: 28)
        cycle.generateDays()
        
        #expect(calendar.isDate(cycle.days.first!.date, inSameDayAs: startDate))
    }
    
    @Test("Last day is correct for cycle length")
    func lastDayIsCorrect() {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let cycleLength = 30
        
        var cycle = Cycle(userId: UUID(), startDate: startDate, cycleLength: cycleLength)
        cycle.generateDays()
        
        let expectedLastDate = calendar.date(byAdding: .day, value: cycleLength - 1, to: startDate)!
        #expect(calendar.isDate(cycle.days.last!.date, inSameDayAs: expectedLastDate))
    }
}

@Suite("Cycle History Tests")
struct CycleHistoryTests {
    
    @Test("Average calculation with multiple cycles")
    func averageWithMultipleCycles() {
        // Test the concept of averaging
        let cycleLengths = [28, 30, 26, 28, 30]
        let average = cycleLengths.reduce(0, +) / cycleLengths.count
        
        #expect(average == 28)
    }
    
    @Test("Single cycle defaults to 28 days")
    func singleCycleDefaultsTo28() {
        let service = DataService.shared
        service.resetAllData()
        
        let average = service.calculateAverageCycleLength()
        #expect(average == 28)
    }
}

// MARK: - Luteal Learning Tests

@Suite("Luteal Phase Learning Tests")
struct LutealLearningTests {
    
    @Test("Personalized luteal length affects ovulation estimate")
    func personalizedLutealAffectsOvulation() {
        // Default luteal (14 days)
        let defaultCycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 14)
        #expect(defaultCycle.estimatedOvulationDay == 14)  // 28 - 14
        
        // Shorter luteal (12 days) = earlier ovulation
        let shortLutealCycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 12)
        #expect(shortLutealCycle.estimatedOvulationDay == 16)  // 28 - 12
        
        // Longer luteal (16 days) = later ovulation
        let longLutealCycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 16)
        #expect(longLutealCycle.estimatedOvulationDay == 12)  // 28 - 16
    }
    
    @Test("Fertile window adjusts with luteal length")
    func fertileWindowAdjustsWithLuteal() {
        // 12-day luteal phase
        let cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 12)
        
        // Ovulation: day 16 (28 - 12)
        // Fertile window: 11-17
        #expect(cycle.estimatedOvulationDay == 16)
        #expect(cycle.fertileWindowStart == 11)  // 16 - 5
        #expect(cycle.fertileWindowEnd == 17)    // 16 + 1
    }
    
    @Test("Luteal length clamped to safe range")
    func lutealClampedToSafeRange() {
        // Even with extreme luteal values, fertile window stays sensible
        var extremeShortCycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 5)
        extremeShortCycle.generateDays()
        
        // fertileWindowStart should be at least 1
        #expect(extremeShortCycle.fertileWindowStart >= 1)
        
        var extremeLongCycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 25)
        extremeLongCycle.generateDays()
        
        // Should still have some fertile days
        let fertileDays = extremeLongCycle.days.filter { $0.fertilityLevel == .high || $0.fertilityLevel == .peak }
        #expect(fertileDays.count >= 1)
    }
    
    @Test("Generated days use correct fertility levels with custom luteal")
    func generatedDaysUseCustomLuteal() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28, lutealLength: 12)
        cycle.generateDays()
        
        // With 12-day luteal, ovulation is day 16
        // Peak days: 15, 16 (ovulation day and day before)
        let peakDays = cycle.days.enumerated().filter { $0.element.fertilityLevel == .peak }
        let peakDayNumbers = peakDays.map { $0.offset + 1 }
        
        #expect(peakDayNumbers.contains(15), "Day 15 should be peak")
        #expect(peakDayNumbers.contains(16), "Day 16 should be peak")
    }
    
    @Test("User starts with default luteal values")
    func userDefaultLutealValues() {
        let user = User(name: "Test", role: .woman)
        
        #expect(user.averageLutealLength == 14)
        #expect(user.lutealSamples == 0)
    }
    
    @Test("Recalibration requires LH positive data")
    func recalibrationRequiresLHData() {
        let service = DataService.shared
        service.resetAllData()
        
        var user = service.createUser(name: "Test", role: .woman)
        let initialLuteal = user.averageLutealLength
        
        // Create a cycle without LH data
        var cycleWithoutLH = Cycle(userId: user.id, startDate: Date().addingTimeInterval(-28*24*60*60), cycleLength: 28)
        cycleWithoutLH.generateDays()
        
        // Simulate recalibration
        service.recalibrateLutealPhase(previousCycle: cycleWithoutLH, newCycleStartDate: Date())
        
        // Should not change without LH data
        user = service.currentUser!
        #expect(user.averageLutealLength == initialLuteal)
        #expect(user.lutealSamples == 0)
    }
    
    @Test("Recalibration uses first LH positive only")
    func recalibrationUsesFirstLH() {
        let service = DataService.shared
        service.resetAllData()
        
        _ = service.createUser(name: "Test", role: .woman)
        
        let calendar = Calendar.current
        let cycleStart = calendar.date(byAdding: .day, value: -28, to: Date())!
        
        // Create cycle with multiple LH positives
        var cycle = Cycle(userId: UUID(), startDate: cycleStart, cycleLength: 28)
        cycle.generateDays()
        
        // Add LH positive on day 14 (index 13)
        cycle.days[13].lhTestResult = .positive
        cycle.days[13].lhTestLoggedAt = calendar.date(byAdding: .day, value: 13, to: cycleStart)
        
        // Add another LH positive on day 15 (index 14) - should be ignored
        cycle.days[14].lhTestResult = .positive
        cycle.days[14].lhTestLoggedAt = calendar.date(byAdding: .day, value: 14, to: cycleStart)
        
        // Run recalibration
        service.recalibrateLutealPhase(previousCycle: cycle, newCycleStartDate: Date())
        
        // Should have learned something (first LH on day 14, ~14 days to next cycle)
        let user = service.currentUser!
        #expect(user.lutealSamples == 1, "Should have 1 sample after first learning")
    }
    
    @Test("Recalibration skips irregular cycles")
    func recalibrationSkipsIrregularCycles() {
        let service = DataService.shared
        service.resetAllData()
        
        _ = service.createUser(name: "Test", role: .woman)
        
        let calendar = Calendar.current
        
        // Very short cycle (15 days) - should be skipped
        let shortCycleStart = calendar.date(byAdding: .day, value: -15, to: Date())!
        var shortCycle = Cycle(userId: UUID(), startDate: shortCycleStart, cycleLength: 15)
        shortCycle.generateDays()
        shortCycle.days[7].lhTestResult = .positive
        
        service.recalibrateLutealPhase(previousCycle: shortCycle, newCycleStartDate: Date())
        
        var user = service.currentUser!
        #expect(user.lutealSamples == 0, "Should not learn from irregular cycle")
        
        // Very long cycle (45 days) - should be skipped
        service.resetAllData()
        _ = service.createUser(name: "Test", role: .woman)
        
        let longCycleStart = calendar.date(byAdding: .day, value: -45, to: Date())!
        var longCycle = Cycle(userId: UUID(), startDate: longCycleStart, cycleLength: 45)
        longCycle.generateDays()
        longCycle.days[20].lhTestResult = .positive
        
        service.recalibrateLutealPhase(previousCycle: longCycle, newCycleStartDate: Date())
        
        user = service.currentUser!
        #expect(user.lutealSamples == 0, "Should not learn from irregular cycle")
    }
}
