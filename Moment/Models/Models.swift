//
//  Models.swift
//  Moment
//
//  Core data models for the fertility tracking app
//

import Foundation
import SwiftUI

// MARK: - User & Couple

enum UserRole: String, Codable {
    case woman = "woman"
    case partner = "partner"
}

enum NotificationTone: String, Codable, CaseIterable {
    case discreet = "discreet"
    case explicit = "explicit"
    
    var displayName: String {
        switch self {
        case .discreet: return "Gentle"
        case .explicit: return "Direct"
        }
    }
    
    var description: String {
        switch self {
        case .discreet: return "\"Check-in time\" — subtle reminders"
        case .explicit: return "\"Fertile window today\" — clear signals"
        }
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    var name: String
    var role: UserRole
    var coupleId: UUID?
    var notificationTone: NotificationTone
    var notificationsEnabled: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, role: UserRole, coupleId: UUID? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.coupleId = coupleId
        self.notificationTone = .discreet
        self.notificationsEnabled = true
        self.createdAt = Date()
    }
}

struct LocalCouple: Codable, Identifiable {
    let id: UUID
    var womanId: UUID
    var partnerId: UUID?
    var inviteCode: String
    var isLinked: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), womanId: UUID) {
        self.id = id
        self.womanId = womanId
        self.partnerId = nil
        self.inviteCode = LocalCouple.generateInviteCode()
        self.isLinked = false
        self.createdAt = Date()
    }
    
    static func generateInviteCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Cycle Tracking

enum FertilityLevel: String, Codable {
    case low = "low"
    case high = "high"
    case peak = "peak"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .high: return "High"
        case .peak: return "Peak"
        }
    }
    
    var shortName: String {
        switch self {
        case .low: return "Low"
        case .high: return "High"
        case .peak: return "Peak"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return Color("LowFertility")
        case .high: return Color("HighFertility")
        case .peak: return Color("PeakFertility")
        }
    }
    
    var partnerColor: Color {
        switch self {
        case .low: return Color("PartnerLow")
        case .high: return Color("PartnerHigh")
        case .peak: return Color("PartnerPeak")
        }
    }
}

enum LHTestResult: String, Codable {
    case negative = "negative"
    case positive = "positive"
    
    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .positive: return "Positive"
        }
    }
}

struct CycleDay: Codable, Identifiable {
    let id: UUID
    let date: Date
    var fertilityLevel: FertilityLevel
    var isMenstruation: Bool
    var lhTestResult: LHTestResult?
    var lhTestLoggedAt: Date?
    var hadIntimacy: Bool
    var intimacyLoggedAt: Date?
    var notes: String?
    
    init(id: UUID = UUID(), date: Date, fertilityLevel: FertilityLevel = .low, isMenstruation: Bool = false, hadIntimacy: Bool = false) {
        self.id = id
        self.date = date
        self.fertilityLevel = fertilityLevel
        self.isMenstruation = isMenstruation
        self.hadIntimacy = hadIntimacy
    }
}

struct Cycle: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var startDate: Date
    var endDate: Date?
    var cycleLength: Int
    var days: [CycleDay]
    var isActive: Bool
    var createdAt: Date
    
    // Estimated values based on cycle history
    var estimatedOvulationDay: Int { cycleLength - 14 }
    var fertileWindowStart: Int { estimatedOvulationDay - 5 }
    var fertileWindowEnd: Int { estimatedOvulationDay + 1 }
    
    init(id: UUID = UUID(), userId: UUID, startDate: Date, cycleLength: Int = 28) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.cycleLength = cycleLength
        self.days = []
        self.isActive = true
        self.createdAt = Date()
    }
    
    mutating func generateDays() {
        days = []
        let calendar = Calendar.current
        
        // Ensure valid cycle length
        let safeCycleLength = max(1, cycleLength)
        
        for dayOffset in 0..<safeCycleLength {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dayNumber = dayOffset + 1
            
            var fertilityLevel: FertilityLevel = .low
            let isMenstruation = dayNumber <= 5
            
            if dayNumber >= fertileWindowStart && dayNumber <= fertileWindowEnd {
                if dayNumber == estimatedOvulationDay || dayNumber == estimatedOvulationDay - 1 {
                    fertilityLevel = .peak
                } else {
                    fertilityLevel = .high
                }
            }
            
            let cycleDay = CycleDay(date: date, fertilityLevel: fertilityLevel, isMenstruation: isMenstruation)
            days.append(cycleDay)
        }
    }
}

// MARK: - Action Card

struct ActionCard {
    let date: Date
    let fertilityLevel: FertilityLevel
    let headline: String
    let recommendation: String
    let isLHPositive: Bool
    
    static func forWoman(fertilityLevel: FertilityLevel, isLHPositive: Bool) -> ActionCard {
        let headline: String
        let recommendation: String
        
        if isLHPositive {
            headline = "LH surge detected"
            recommendation = "Ovulation likely within 24-36 hours"
        } else {
            switch fertilityLevel {
            case .peak:
                headline = "Peak fertility"
                recommendation = "This is your most fertile time"
            case .high:
                headline = "High fertility"
                recommendation = "Good timing for intimacy"
            case .low:
                headline = "Low fertility"
                recommendation = "Rest and recharge"
            }
        }
        
        return ActionCard(date: Date(), fertilityLevel: fertilityLevel, headline: headline, recommendation: recommendation, isLHPositive: isLHPositive)
    }
    
    static func forPartner(fertilityLevel: FertilityLevel, isLHPositive: Bool, tone: NotificationTone) -> ActionCard {
        let headline: String
        let recommendation: String
        
        if isLHPositive {
            headline = tone == .explicit ? "Peak fertility today" : "Important check-in"
            recommendation = tone == .explicit ? "Best time for intimacy" : "Connect with your partner"
        } else {
            switch fertilityLevel {
            case .peak:
                headline = tone == .explicit ? "Peak fertility" : "Special moment"
                recommendation = tone == .explicit ? "Great timing today or tomorrow" : "Time to connect"
            case .high:
                headline = tone == .explicit ? "High fertility" : "Good timing"
                recommendation = tone == .explicit ? "Consider today or tomorrow" : "Your partner may want to connect"
            case .low:
                headline = "Quiet time"
                recommendation = "No action needed"
            }
        }
        
        return ActionCard(date: Date(), fertilityLevel: fertilityLevel, headline: headline, recommendation: recommendation, isLHPositive: isLHPositive)
    }
}

// MARK: - Notification Models

enum NotificationType: String, Codable {
    case dailyFertility = "daily_fertility"
    case lhReminder = "lh_reminder"
    case lhPositive = "lh_positive"
    case cycleStart = "cycle_start"
}

struct ScheduledNotification: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let userId: UUID
    let scheduledFor: Date
    var content: String
    var isSent: Bool
    
    init(id: UUID = UUID(), type: NotificationType, userId: UUID, scheduledFor: Date, content: String) {
        self.id = id
        self.type = type
        self.userId = userId
        self.scheduledFor = scheduledFor
        self.content = content
        self.isSent = false
    }
}
