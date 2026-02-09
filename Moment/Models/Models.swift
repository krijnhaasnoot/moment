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
    
    // Cycle learning: personalized luteal phase based on LH test history
    // These refine ovulation timing estimates over multiple cycles
    var averageLutealLength: Int  // Days from LH surge to next period (default: 14)
    var lutealSamples: Int        // Number of confirmed LH→period observations
    
    init(id: UUID = UUID(), name: String, role: UserRole, coupleId: UUID? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.coupleId = coupleId
        self.notificationTone = .discreet
        self.notificationsEnabled = true
        self.createdAt = Date()
        self.averageLutealLength = 14  // Standard assumption until personalized
        self.lutealSamples = 0
    }
    
    // Custom decoding to handle migration from old data without new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(UserRole.self, forKey: .role)
        coupleId = try container.decodeIfPresent(UUID.self, forKey: .coupleId)
        notificationTone = try container.decodeIfPresent(NotificationTone.self, forKey: .notificationTone) ?? .discreet
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        // New fields with defaults for migration
        averageLutealLength = try container.decodeIfPresent(Int.self, forKey: .averageLutealLength) ?? 14
        lutealSamples = try container.decodeIfPresent(Int.self, forKey: .lutealSamples) ?? 0
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, role, coupleId, notificationTone, notificationsEnabled, createdAt, averageLutealLength, lutealSamples
    }
}

struct LocalCouple: Codable, Identifiable {
    let id: UUID
    var womanId: UUID?  // Optional: null when partner creates the couple
    var partnerId: UUID?
    var inviteCode: String
    var isLinked: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), womanId: UUID? = nil, partnerId: UUID? = nil) {
        self.id = id
        self.womanId = womanId
        self.partnerId = partnerId
        self.inviteCode = LocalCouple.generateInviteCode()
        self.isLinked = false
        self.createdAt = Date()
    }
    
    // Custom decoding to handle migration and womanId becoming optional
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        womanId = try container.decodeIfPresent(UUID.self, forKey: .womanId)
        partnerId = try container.decodeIfPresent(UUID.self, forKey: .partnerId)
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode) ?? LocalCouple.generateInviteCode()
        isLinked = try container.decodeIfPresent(Bool.self, forKey: .isLinked) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, womanId, partnerId, inviteCode, isLinked, createdAt
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

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    var displayName: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    var fullName: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }
    
    /// Convert Celsius to display value based on unit preference
    func displayValue(from celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9/5) + 32
        }
    }
    
    /// Convert display value to Celsius for storage
    func toCelsius(from value: Double) -> Double {
        switch self {
        case .celsius: return value
        case .fahrenheit: return (value - 32) * 5/9
        }
    }
    
    /// Format temperature for display
    func format(_ celsius: Double) -> String {
        let value = displayValue(from: celsius)
        return String(format: "%.1f%@", value, displayName)
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
    // Temperature tracking (optional)
    // Note: Temperature is currently stored and displayed only.
    // It is NOT used to drive ovulation prediction or fertile window logic.
    // Future versions may use temperature as a secondary confirmation signal.
    var temperature: Double?  // Stored in Celsius
    var temperatureLoggedAt: Date?
    
    init(id: UUID = UUID(), date: Date, fertilityLevel: FertilityLevel = .low, isMenstruation: Bool = false, hadIntimacy: Bool = false) {
        self.id = id
        // Normalize to start of day to avoid timezone issues
        self.date = Calendar.current.startOfDay(for: date)
        self.fertilityLevel = fertilityLevel
        self.isMenstruation = isMenstruation
        self.hadIntimacy = hadIntimacy
    }
    
    // Custom decoding to handle migration from old data without intimacy/temperature fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        fertilityLevel = try container.decodeIfPresent(FertilityLevel.self, forKey: .fertilityLevel) ?? .low
        isMenstruation = try container.decodeIfPresent(Bool.self, forKey: .isMenstruation) ?? false
        lhTestResult = try container.decodeIfPresent(LHTestResult.self, forKey: .lhTestResult)
        lhTestLoggedAt = try container.decodeIfPresent(Date.self, forKey: .lhTestLoggedAt)
        // Fields with defaults for migration
        hadIntimacy = try container.decodeIfPresent(Bool.self, forKey: .hadIntimacy) ?? false
        intimacyLoggedAt = try container.decodeIfPresent(Date.self, forKey: .intimacyLoggedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        // Temperature fields (optional, null by default)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        temperatureLoggedAt = try container.decodeIfPresent(Date.self, forKey: .temperatureLoggedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, date, fertilityLevel, isMenstruation, lhTestResult, lhTestLoggedAt, hadIntimacy, intimacyLoggedAt, notes, temperature, temperatureLoggedAt
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
    
    // Personalized luteal length for this cycle (stored for historical accuracy)
    var lutealLength: Int
    
    // Estimated ovulation based on personalized luteal phase length
    // Ovulation typically occurs lutealLength days before the next period
    var estimatedOvulationDay: Int { max(1, cycleLength - lutealLength) }
    var fertileWindowStart: Int { max(1, estimatedOvulationDay - 5) }
    var fertileWindowEnd: Int { min(cycleLength, estimatedOvulationDay + 1) }
    
    init(id: UUID = UUID(), userId: UUID, startDate: Date, cycleLength: Int = 28, lutealLength: Int = 14) {
        self.id = id
        self.userId = userId
        // Normalize to start of day to avoid timezone issues
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.cycleLength = cycleLength
        self.lutealLength = lutealLength
        self.days = []
        self.isActive = true
        self.createdAt = Date()
    }
    
    // Custom decoding to handle migration from old data without lutealLength field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        cycleLength = try container.decodeIfPresent(Int.self, forKey: .cycleLength) ?? 28
        days = try container.decodeIfPresent([CycleDay].self, forKey: .days) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        // New field with default for migration
        lutealLength = try container.decodeIfPresent(Int.self, forKey: .lutealLength) ?? 14
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, userId, startDate, endDate, cycleLength, days, isActive, createdAt, lutealLength
    }
    
    /// Generate cycle days with fertility levels based on personalized luteal phase
    mutating func generateDays() {
        days = []
        let calendar = Calendar.current
        
        // Ensure valid cycle length
        let safeCycleLength = max(1, cycleLength)
        
        // Ensure startDate is normalized
        let normalizedStart = calendar.startOfDay(for: startDate)
        
        for dayOffset in 0..<safeCycleLength {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: normalizedStart) else { continue }
            let dayNumber = dayOffset + 1
            
            var fertilityLevel: FertilityLevel = .low
            let isMenstruation = dayNumber <= 5
            
            // Fertile window: 5 days before ovulation to 1 day after
            if dayNumber >= fertileWindowStart && dayNumber <= fertileWindowEnd {
                // Peak: ovulation day and day before (highest probability)
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
    case lhReminder = "lh_reminder"  // Deprecated: LH reminders removed, kept for backwards compatibility
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
