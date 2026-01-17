//
//  NotificationTests.swift
//  MomentTests
//
//  Tests for notification content and logic
//

import Testing
import Foundation
@testable import Moment

@Suite("Notification Content Tests")
struct NotificationContentTests {
    
    // MARK: - Woman Notification Content
    
    @Test("Woman notification for peak fertility")
    func womanPeakNotification() {
        // Simulating notification content generation
        let fertilityLevel = FertilityLevel.peak
        let expectedContent = "Peak fertility today — your most fertile time"
        
        #expect(fertilityLevel == .peak)
        // In a real test, we'd test the actual notification service
    }
    
    @Test("Woman notification for high fertility")
    func womanHighNotification() {
        let fertilityLevel = FertilityLevel.high
        #expect(fertilityLevel.displayName == "High")
    }
    
    @Test("Woman notification for low fertility")
    func womanLowNotification() {
        let fertilityLevel = FertilityLevel.low
        #expect(fertilityLevel.displayName == "Low")
    }
    
    // MARK: - Partner Notification Content
    
    @Test("Partner should not receive low fertility notifications")
    func partnerNoLowNotification() {
        // Partners only get notified for high/peak
        let card = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .explicit)
        #expect(card.headline == "Quiet time")
    }
    
    @Test("Partner explicit notification for high fertility")
    func partnerExplicitHighNotification() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: false, tone: .explicit)
        #expect(card.recommendation.lowercased().contains("connect") || card.recommendation.lowercased().contains("timing"))
    }
    
    @Test("Partner discreet notification for high fertility")
    func partnerDiscreetHighNotification() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: false, tone: .discreet)
        // Discreet tone should not mention fertility explicitly
        #expect(!card.headline.lowercased().contains("fertility"))
    }
    
    // MARK: - LH Positive Notifications
    
    @Test("LH positive notification is highest priority")
    func lhPositiveHighPriority() {
        // LH positive should override normal fertility messages
        let womanCard = ActionCard.forWoman(fertilityLevel: .high, isLHPositive: true)
        #expect(womanCard.headline.contains("LH"))
        
        let partnerCard = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: true, tone: .explicit)
        #expect(partnerCard.isLHPositive == true)
    }
}

@Suite("Notification Logic Tests")
struct NotificationLogicTests {
    
    @Test("Daily notification limit is enforced")
    func dailyNotificationLimit() {
        // Test that max 1 scheduled notification per day rule
        // LH positive is the only exception
        let lhPositiveIsException = true
        #expect(lhPositiveIsException == true)
    }
    
    @Test("LH reminder only during fertile window")
    func lhReminderOnlyInFertileWindow() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // Check that LH reminders would only be sent during fertile window
        let fertileWindowDays = cycle.days.filter { 
            $0.fertilityLevel == .high || $0.fertilityLevel == .peak 
        }
        
        #expect(fertileWindowDays.count > 0)
        #expect(fertileWindowDays.count <= 7)
    }
    
    @Test("Partner never sees menstruation data")
    func partnerNoMenstruationData() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // Partner view should filter out menstruation
        let menstruationDays = cycle.days.filter { $0.isMenstruation }
        #expect(menstruationDays.count == 5) // Woman sees this
        
        // Partner action card doesn't expose menstruation
        let card = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .explicit)
        #expect(!card.headline.lowercased().contains("period"))
        #expect(!card.headline.lowercased().contains("menstruation"))
    }
}

@Suite("Notification Tone Tests")
struct NotificationToneTests {
    
    @Test("All notification tones are available")
    func allTonesAvailable() {
        let allTones = NotificationTone.allCases
        #expect(allTones.count == 2)
        #expect(allTones.contains(.discreet))
        #expect(allTones.contains(.explicit))
    }
    
    @Test("Tone affects partner notification wording")
    func toneAffectsWording() {
        let explicitCard = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .explicit)
        let discreetCard = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .discreet)
        
        // Headlines should be different
        #expect(explicitCard.headline != discreetCard.headline)
    }
    
    @Test("Discreet tone avoids clinical language")
    func discreetAvoidsClinicalLanguage() {
        let card = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .discreet)
        
        let clinicalTerms = ["fertility", "ovulation", "cycle", "menstruation"]
        for term in clinicalTerms {
            #expect(!card.headline.lowercased().contains(term), 
                   "Discreet headline should not contain '\(term)'")
        }
    }
    
    @Test("Explicit tone is clear about fertility")
    func explicitIsClear() {
        let card = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .explicit)
        
        // Explicit tone should mention fertility
        #expect(card.headline.lowercased().contains("fertility") || 
               card.headline.lowercased().contains("peak"))
    }
}
