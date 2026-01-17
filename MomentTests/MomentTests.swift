//
//  MomentTests.swift
//  MomentTests
//
//  Unit tests for Moment fertility tracking app
//

import Testing
import Foundation
@testable import Moment

// MARK: - Model Tests

@Suite("Model Tests")
struct ModelTests {
    
    // MARK: - User Tests
    
    @Test("User creation with default values")
    func userCreation() {
        let user = User(name: "Sarah", role: .woman)
        
        #expect(user.name == "Sarah")
        #expect(user.role == .woman)
        #expect(user.notificationTone == .discreet)
        #expect(user.notificationsEnabled == true)
        #expect(user.coupleId == nil)
    }
    
    @Test("User creation as partner")
    func partnerUserCreation() {
        let coupleId = UUID()
        let user = User(name: "John", role: .partner, coupleId: coupleId)
        
        #expect(user.name == "John")
        #expect(user.role == .partner)
        #expect(user.coupleId == coupleId)
    }
    
    // MARK: - Couple Tests
    
    @Test("Couple creation generates invite code")
    func coupleCreation() {
        let womanId = UUID()
        let couple = LocalCouple(womanId: womanId)
        
        #expect(couple.womanId == womanId)
        #expect(couple.partnerId == nil)
        #expect(couple.isLinked == false)
        #expect(couple.inviteCode.count == 6)
    }
    
    @Test("Invite code contains only valid characters")
    func inviteCodeCharacters() {
        let validChars = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        
        for _ in 0..<100 {
            let code = LocalCouple.generateInviteCode()
            #expect(code.count == 6)
            for char in code {
                #expect(validChars.contains(char), "Invalid character in invite code: \(char)")
            }
        }
    }
    
    // MARK: - Notification Tone Tests
    
    @Test("Notification tone display names")
    func notificationToneDisplayNames() {
        #expect(NotificationTone.discreet.displayName == "Gentle")
        #expect(NotificationTone.explicit.displayName == "Direct")
    }
    
    @Test("Notification tone descriptions")
    func notificationToneDescriptions() {
        #expect(NotificationTone.discreet.description.contains("subtle"))
        #expect(NotificationTone.explicit.description.contains("clear"))
    }
}

// MARK: - Cycle Tests

@Suite("Cycle Tests")
struct CycleTests {
    
    @Test("Cycle creation with default length")
    func cycleCreationDefault() {
        let userId = UUID()
        let startDate = Date()
        let cycle = Cycle(userId: userId, startDate: startDate)
        
        #expect(cycle.userId == userId)
        #expect(cycle.cycleLength == 28)
        #expect(cycle.isActive == true)
        #expect(cycle.endDate == nil)
    }
    
    @Test("Cycle creation with custom length")
    func cycleCreationCustomLength() {
        let userId = UUID()
        let startDate = Date()
        let cycle = Cycle(userId: userId, startDate: startDate, cycleLength: 30)
        
        #expect(cycle.cycleLength == 30)
    }
    
    @Test("Estimated ovulation day calculation")
    func ovulationDayCalculation() {
        let cycle28 = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        #expect(cycle28.estimatedOvulationDay == 14)
        
        let cycle30 = Cycle(userId: UUID(), startDate: Date(), cycleLength: 30)
        #expect(cycle30.estimatedOvulationDay == 16)
        
        let cycle26 = Cycle(userId: UUID(), startDate: Date(), cycleLength: 26)
        #expect(cycle26.estimatedOvulationDay == 12)
    }
    
    @Test("Fertile window calculation")
    func fertileWindowCalculation() {
        let cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        
        // Ovulation day 14, fertile window should be day 9-15
        #expect(cycle.fertileWindowStart == 9)
        #expect(cycle.fertileWindowEnd == 15)
    }
    
    @Test("Cycle day generation creates correct number of days")
    func cycleDayGeneration() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        #expect(cycle.days.count == 28)
    }
    
    @Test("Cycle day generation marks menstruation correctly")
    func menstruationMarking() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // First 5 days should be menstruation
        for i in 0..<5 {
            #expect(cycle.days[i].isMenstruation == true, "Day \(i+1) should be menstruation")
        }
        
        // Day 6 onwards should not be menstruation
        for i in 5..<cycle.days.count {
            #expect(cycle.days[i].isMenstruation == false, "Day \(i+1) should not be menstruation")
        }
    }
    
    @Test("Cycle day generation sets fertility levels correctly")
    func fertilityLevelAssignment() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // Check some key days
        // Days 1-8: Low
        #expect(cycle.days[0].fertilityLevel == .low)
        #expect(cycle.days[7].fertilityLevel == .low)
        
        // Days 9-12: High (fertile window start)
        #expect(cycle.days[8].fertilityLevel == .high)  // Day 9
        #expect(cycle.days[9].fertilityLevel == .high)  // Day 10
        
        // Days 13-14: Peak (around ovulation)
        #expect(cycle.days[12].fertilityLevel == .peak) // Day 13
        #expect(cycle.days[13].fertilityLevel == .peak) // Day 14
        
        // Days 16+: Low
        #expect(cycle.days[15].fertilityLevel == .low)  // Day 16
        #expect(cycle.days[27].fertilityLevel == .low)  // Day 28
    }
}

// MARK: - Cycle Day Tests

@Suite("Cycle Day Tests")
struct CycleDayTests {
    
    @Test("Cycle day default values")
    func cycleDayDefaults() {
        let day = CycleDay(date: Date())
        
        #expect(day.fertilityLevel == .low)
        #expect(day.isMenstruation == false)
        #expect(day.lhTestResult == nil)
        #expect(day.lhTestLoggedAt == nil)
    }
    
    @Test("Cycle day with menstruation")
    func cycleDayWithMenstruation() {
        let day = CycleDay(date: Date(), fertilityLevel: .low, isMenstruation: true)
        
        #expect(day.isMenstruation == true)
    }
    
    @Test("LH test result values")
    func lhTestResultValues() {
        #expect(LHTestResult.negative.displayName == "Negative")
        #expect(LHTestResult.positive.displayName == "Positive")
    }
}

// MARK: - Fertility Level Tests

@Suite("Fertility Level Tests")
struct FertilityLevelTests {
    
    @Test("Fertility level display names")
    func displayNames() {
        #expect(FertilityLevel.low.displayName == "Low")
        #expect(FertilityLevel.high.displayName == "High")
        #expect(FertilityLevel.peak.displayName == "Peak")
    }
    
    @Test("Fertility levels are ordered correctly")
    func fertilityLevelOrdering() {
        let levels: [FertilityLevel] = [.low, .high, .peak]
        #expect(levels.count == 3)
    }
}

// MARK: - Action Card Tests

@Suite("Action Card Tests")
struct ActionCardTests {
    
    @Test("Woman action card - peak fertility")
    func womanActionCardPeak() {
        let card = ActionCard.forWoman(fertilityLevel: .peak, isLHPositive: false)
        
        #expect(card.headline == "Peak fertility")
        #expect(card.recommendation.contains("most fertile"))
        #expect(card.fertilityLevel == .peak)
    }
    
    @Test("Woman action card - high fertility")
    func womanActionCardHigh() {
        let card = ActionCard.forWoman(fertilityLevel: .high, isLHPositive: false)
        
        #expect(card.headline == "High fertility")
        #expect(card.recommendation.contains("Good timing"))
    }
    
    @Test("Woman action card - low fertility")
    func womanActionCardLow() {
        let card = ActionCard.forWoman(fertilityLevel: .low, isLHPositive: false)
        
        #expect(card.headline == "Low fertility")
        #expect(card.recommendation.contains("Rest"))
    }
    
    @Test("Woman action card - LH positive overrides")
    func womanActionCardLHPositive() {
        let card = ActionCard.forWoman(fertilityLevel: .high, isLHPositive: true)
        
        #expect(card.headline == "LH surge detected")
        #expect(card.recommendation.contains("24-36 hours"))
        #expect(card.isLHPositive == true)
    }
    
    @Test("Partner action card - explicit tone, peak")
    func partnerActionCardExplicitPeak() {
        let card = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .explicit)
        
        #expect(card.headline == "Peak fertility")
        #expect(card.recommendation.contains("Great timing"))
    }
    
    @Test("Partner action card - discreet tone, peak")
    func partnerActionCardDiscreetPeak() {
        let card = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .discreet)
        
        #expect(card.headline == "Special moment")
        #expect(card.recommendation.contains("connect"))
    }
    
    @Test("Partner action card - low fertility shows quiet time")
    func partnerActionCardLow() {
        let card = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .explicit)
        
        #expect(card.headline == "Quiet time")
        #expect(card.recommendation.contains("No action"))
    }
    
    @Test("Partner action card - LH positive explicit")
    func partnerActionCardLHPositiveExplicit() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: true, tone: .explicit)
        
        #expect(card.headline.contains("Peak fertility"))
        #expect(card.recommendation.contains("Best time"))
    }
    
    @Test("Partner action card - LH positive discreet")
    func partnerActionCardLHPositiveDiscreet() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: true, tone: .discreet)
        
        #expect(card.headline.contains("check-in"))
        #expect(card.recommendation.contains("Connect"))
    }
}

// MARK: - Data Service Tests

@Suite("Data Service Tests")
struct DataServiceTests {
    
    @Test("Calculate average cycle length with no history")
    func averageCycleLengthNoHistory() {
        let service = DataService.shared
        service.resetAllData()
        
        let average = service.calculateAverageCycleLength()
        #expect(average == 28) // Default when no history
    }
    
    @Test("Create user sets up couple for woman")
    func createUserWomanSetupCouple() {
        let service = DataService.shared
        service.resetAllData()
        
        let user = service.createUser(name: "Sarah", role: .woman)
        
        #expect(user.role == .woman)
        #expect(service.couple != nil)
        #expect(service.couple?.womanId == user.id)
        #expect(service.currentUser?.coupleId != nil)
    }
    
    @Test("Create user does not set up couple for partner")
    func createUserPartnerNoCouple() {
        let service = DataService.shared
        service.resetAllData()
        
        let user = service.createUser(name: "John", role: .partner)
        
        #expect(user.role == .partner)
        #expect(user.coupleId == nil)
    }
    
    @Test("Reset all data clears everything")
    func resetAllDataClears() {
        let service = DataService.shared
        
        // Create some data
        _ = service.createUser(name: "Test", role: .woman)
        _ = service.startNewCycle(startDate: Date())
        
        // Reset
        service.resetAllData()
        
        #expect(service.currentUser == nil)
        #expect(service.couple == nil)
        #expect(service.cycles.isEmpty)
        #expect(service.isOnboardingComplete == false)
    }
}

// MARK: - Date Helper Tests

@Suite("Date Helper Tests")
struct DateHelperTests {
    
    @Test("Days in fertile window are correctly identified")
    func daysInFertileWindow() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        let fertileWindowDays = cycle.days.filter { 
            $0.fertilityLevel == .high || $0.fertilityLevel == .peak 
        }
        
        // Should be 7 days in fertile window (days 9-15)
        #expect(fertileWindowDays.count == 7)
    }
    
    @Test("Peak fertility days are around ovulation")
    func peakDaysAroundOvulation() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        let peakDays = cycle.days.filter { $0.fertilityLevel == .peak }
        
        // Should be 2 peak days (day 13 and 14 for 28-day cycle)
        #expect(peakDays.count == 2)
    }
}
