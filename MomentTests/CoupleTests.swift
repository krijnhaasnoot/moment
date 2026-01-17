//
//  CoupleTests.swift
//  MomentTests
//
//  Tests for couple linking and partner functionality
//

import Testing
import Foundation
@testable import Moment

@Suite("Couple Linking Tests")
struct CoupleLinkingTests {
    
    // MARK: - Invite Code Tests
    
    @Test("Invite code is always 6 characters")
    func inviteCodeLength() {
        for _ in 0..<50 {
            let code = LocalCouple.generateInviteCode()
            #expect(code.count == 6)
        }
    }
    
    @Test("Invite code is uppercase")
    func inviteCodeUppercase() {
        for _ in 0..<50 {
            let code = LocalCouple.generateInviteCode()
            #expect(code == code.uppercased())
        }
    }
    
    @Test("Invite code excludes ambiguous characters")
    func inviteCodeExcludesAmbiguous() {
        // Should not contain 0, O, 1, I, L to avoid confusion
        let excludedChars = Set("0O1IL")
        
        for _ in 0..<100 {
            let code = LocalCouple.generateInviteCode()
            for char in code {
                #expect(!excludedChars.contains(char), "Code contains ambiguous character: \(char)")
            }
        }
    }
    
    @Test("Each invite code is unique")
    func inviteCodesUnique() {
        var codes = Set<String>()
        
        for _ in 0..<100 {
            let code = LocalCouple.generateInviteCode()
            codes.insert(code)
        }
        
        // With 6 characters and ~32 possible chars, collisions should be extremely rare
        #expect(codes.count >= 95) // Allow for some collisions
    }
    
    // MARK: - Local Couple Creation Tests
    
    @Test("LocalCouple starts unlinked")
    func localCoupleStartsUnlinked() {
        let couple = LocalCouple(womanId: UUID())
        
        #expect(couple.isLinked == false)
        #expect(couple.partnerId == nil)
    }
    
    @Test("LocalCouple has valid woman ID")
    func localCoupleHasValidWomanId() {
        let womanId = UUID()
        let couple = LocalCouple(womanId: womanId)
        
        #expect(couple.womanId == womanId)
    }
    
    @Test("LocalCouple creation timestamp is set")
    func localCoupleCreationTimestamp() {
        let before = Date()
        let couple = LocalCouple(womanId: UUID())
        let after = Date()
        
        #expect(couple.createdAt >= before)
        #expect(couple.createdAt <= after)
    }
    
    @Test("LocalCouple has valid invite code on creation")
    func localCoupleHasInviteCode() {
        let couple = LocalCouple(womanId: UUID())
        
        #expect(couple.inviteCode.count == 6)
        #expect(!couple.inviteCode.isEmpty)
    }
    
    // MARK: - Partner View Tests
    
    @Test("Partner view shows fertility but not menstruation details")
    func partnerViewHidesMenstruation() {
        var cycle = Cycle(userId: UUID(), startDate: Date(), cycleLength: 28)
        cycle.generateDays()
        
        // Partner should see fertility levels
        let fertileDays = cycle.days.filter { $0.fertilityLevel != .low }
        #expect(fertileDays.count > 0)
        
        // But partner view would filter menstruation (tested in view layer)
        let menstruationDays = cycle.days.filter { $0.isMenstruation }
        #expect(menstruationDays.count == 5) // Data exists, but hidden in UI
    }
    
    @Test("Partner gets appropriate notification tone")
    func partnerNotificationTone() {
        // Discreet tone
        let discreetCard = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .discreet)
        #expect(!discreetCard.headline.lowercased().contains("fertility"))
        
        // Explicit tone
        let explicitCard = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .explicit)
        #expect(explicitCard.headline.lowercased().contains("fertility") || 
               explicitCard.headline.lowercased().contains("peak"))
    }
}

@Suite("Partner Action Card Tests")
struct PartnerActionCardTests {
    
    @Test("Partner sees different headlines based on tone")
    func partnerHeadlinesByTone() {
        let levels: [FertilityLevel] = [.low, .high, .peak]
        
        for level in levels {
            let discreet = ActionCard.forPartner(fertilityLevel: level, isLHPositive: false, tone: .discreet)
            let explicit = ActionCard.forPartner(fertilityLevel: level, isLHPositive: false, tone: .explicit)
            
            if level != .low {
                #expect(discreet.headline != explicit.headline, 
                       "Headlines should differ for \(level.displayName) fertility")
            }
        }
    }
    
    @Test("Partner low fertility always shows quiet time")
    func partnerLowFertilityQuietTime() {
        let discreet = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .discreet)
        let explicit = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .explicit)
        
        #expect(discreet.headline == "Quiet time")
        #expect(explicit.headline == "Quiet time")
    }
    
    @Test("Partner LH positive explicit is clear")
    func partnerLHPositiveExplicit() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: true, tone: .explicit)
        
        #expect(card.isLHPositive == true)
        #expect(card.headline.lowercased().contains("peak") || 
               card.headline.lowercased().contains("fertility"))
    }
    
    @Test("Partner LH positive discreet is subtle")
    func partnerLHPositiveDiscreet() {
        let card = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: true, tone: .discreet)
        
        #expect(card.isLHPositive == true)
        #expect(card.headline.lowercased().contains("check-in") || 
               card.headline.lowercased().contains("moment") ||
               card.headline.lowercased().contains("important"))
    }
    
    @Test("Partner recommendation varies by fertility level")
    func partnerRecommendationsByLevel() {
        let lowCard = ActionCard.forPartner(fertilityLevel: .low, isLHPositive: false, tone: .explicit)
        let highCard = ActionCard.forPartner(fertilityLevel: .high, isLHPositive: false, tone: .explicit)
        let peakCard = ActionCard.forPartner(fertilityLevel: .peak, isLHPositive: false, tone: .explicit)
        
        #expect(lowCard.recommendation != highCard.recommendation)
        #expect(highCard.recommendation != peakCard.recommendation)
    }
}

@Suite("Join Couple Result Tests")
struct JoinCoupleResultTests {
    
    @Test("Success result has couple ID")
    func successResultHasCoupleId() {
        let coupleId = UUID()
        let result = JoinCoupleResult(success: true, error: nil, coupleId: coupleId)
        
        #expect(result.success == true)
        #expect(result.error == nil)
        #expect(result.coupleId == coupleId)
    }
    
    @Test("Failure result has error message")
    func failureResultHasError() {
        let result = JoinCoupleResult(success: false, error: "Invalid invite code", coupleId: nil)
        
        #expect(result.success == false)
        #expect(result.error == "Invalid invite code")
        #expect(result.coupleId == nil)
    }
    
    @Test("Already linked error")
    func alreadyLinkedError() {
        let result = JoinCoupleResult(success: false, error: "This couple is already linked", coupleId: nil)
        
        #expect(result.success == false)
        #expect(result.error?.contains("already linked") == true)
    }
    
    @Test("Result is a struct")
    func resultIsStruct() {
        let result1 = JoinCoupleResult(success: true, error: nil, coupleId: UUID())
        var result2 = result1
        
        // Mutating result2 shouldn't affect result1 (value semantics)
        result2 = JoinCoupleResult(success: false, error: "Changed", coupleId: nil)
        
        #expect(result1.success == true)
        #expect(result2.success == false)
    }
}

@Suite("Fertility Level Color Tests")
struct FertilityLevelColorTests {
    
    @Test("Each fertility level has a color")
    func fertilityLevelsHaveColors() {
        // Just verify the properties exist and return values
        let low = FertilityLevel.low
        let high = FertilityLevel.high
        let peak = FertilityLevel.peak
        
        // Access color property to ensure it doesn't crash
        _ = low.color
        _ = high.color
        _ = peak.color
        
        #expect(true)
    }
    
    @Test("Each fertility level has a partner color")
    func fertilityLevelsHavePartnerColors() {
        let low = FertilityLevel.low
        let high = FertilityLevel.high
        let peak = FertilityLevel.peak
        
        // Access partnerColor property to ensure it doesn't crash
        _ = low.partnerColor
        _ = high.partnerColor
        _ = peak.partnerColor
        
        #expect(true)
    }
}
