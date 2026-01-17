//
//  ProfileTests.swift
//  MomentTests
//
//  Tests for user profile and settings functionality
//

import Testing
import Foundation
@testable import Moment

@Suite("Profile Model Tests")
struct ProfileModelTests {
    
    // MARK: - Profile Creation
    
    @Test("Profile has required fields")
    func profileRequiredFields() {
        let id = UUID()
        let profile = Profile(
            id: id,
            name: "Sarah",
            role: "woman",
            coupleId: nil,
            notificationTone: "discreet",
            notificationsEnabled: true,
            pushToken: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(profile.id == id)
        #expect(profile.name == "Sarah")
        #expect(profile.role == "woman")
        #expect(profile.notificationsEnabled == true)
    }
    
    @Test("Profile is codable")
    func profileIsCodable() throws {
        let original = Profile(
            id: UUID(),
            name: "Test",
            role: "woman",
            coupleId: UUID(),
            notificationTone: "explicit",
            notificationsEnabled: false,
            pushToken: "token123",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(Profile.self, from: encoded)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.role == original.role)
        #expect(decoded.notificationTone == original.notificationTone)
        #expect(decoded.notificationsEnabled == original.notificationsEnabled)
    }
    
    // MARK: - Profile Update
    
    @Test("Profile update with name")
    func profileUpdateWithName() {
        let update = ProfileUpdate(name: "New Name")
        
        #expect(update.name == "New Name")
        #expect(update.notificationTone == nil)
        #expect(update.notificationsEnabled == nil)
    }
    
    @Test("Profile update with notification settings")
    func profileUpdateWithNotifications() {
        let update = ProfileUpdate(notificationTone: "explicit", notificationsEnabled: false)
        
        #expect(update.name == nil)
        #expect(update.notificationTone == "explicit")
        #expect(update.notificationsEnabled == false)
    }
    
    @Test("Profile update with push token")
    func profileUpdateWithPushToken() {
        let update = ProfileUpdate(pushToken: "new-token-123")
        
        #expect(update.pushToken == "new-token-123")
        #expect(update.name == nil)
    }
}

@Suite("User Settings Tests")
struct UserSettingsTests {
    
    // MARK: - Notification Tone Tests
    
    @Test("All notification tones are available")
    func allNotificationTones() {
        let tones = NotificationTone.allCases
        
        #expect(tones.count == 2)
        #expect(tones.contains(.discreet))
        #expect(tones.contains(.explicit))
    }
    
    @Test("Notification tone raw values")
    func notificationToneRawValues() {
        #expect(NotificationTone.discreet.rawValue == "discreet")
        #expect(NotificationTone.explicit.rawValue == "explicit")
    }
    
    @Test("Notification tone from string")
    func notificationToneFromString() {
        #expect(NotificationTone(rawValue: "discreet") == .discreet)
        #expect(NotificationTone(rawValue: "explicit") == .explicit)
        #expect(NotificationTone(rawValue: "invalid") == nil)
    }
    
    @Test("Notification tone display names")
    func notificationToneDisplayNames() {
        #expect(NotificationTone.discreet.displayName == "Gentle")
        #expect(NotificationTone.explicit.displayName == "Direct")
    }
    
    // MARK: - User Role Tests
    
    @Test("User roles are distinct")
    func userRolesDistinct() {
        let roles: [UserRole] = [.woman, .partner]
        #expect(roles.count == 2)
        #expect(roles[0] != roles[1])
    }
    
    @Test("User role raw values")
    func userRoleRawValues() {
        #expect(UserRole.woman.rawValue == "woman")
        #expect(UserRole.partner.rawValue == "partner")
    }
    
    @Test("User role from string")
    func userRoleFromString() {
        #expect(UserRole(rawValue: "woman") == .woman)
        #expect(UserRole(rawValue: "partner") == .partner)
        #expect(UserRole(rawValue: "invalid") == nil)
    }
    
    // MARK: - User Preferences
    
    @Test("Default notification tone is discreet")
    func defaultNotificationTone() {
        let user = User(name: "Test", role: .woman)
        #expect(user.notificationTone == .discreet)
    }
    
    @Test("Default notifications are enabled")
    func defaultNotificationsEnabled() {
        let user = User(name: "Test", role: .woman)
        #expect(user.notificationsEnabled == true)
    }
    
    @Test("User can have custom notification settings")
    func customNotificationSettings() {
        var user = User(name: "Test", role: .woman)
        user.notificationTone = .explicit
        user.notificationsEnabled = false
        
        #expect(user.notificationTone == .explicit)
        #expect(user.notificationsEnabled == false)
    }
}

@Suite("Profile Insert Tests")
struct ProfileInsertTests {
    
    @Test("Profile insert has all required fields")
    func profileInsertFields() {
        let id = UUID()
        let insert = ProfileInsert(
            id: id,
            name: "Test User",
            role: "woman",
            notificationTone: "discreet",
            notificationsEnabled: true
        )
        
        #expect(insert.id == id)
        #expect(insert.name == "Test User")
        #expect(insert.role == "woman")
        #expect(insert.notificationTone == "discreet")
        #expect(insert.notificationsEnabled == true)
    }
    
    @Test("Profile insert is encodable")
    func profileInsertEncodable() throws {
        let insert = ProfileInsert(
            id: UUID(),
            name: "Test",
            role: "partner",
            notificationTone: "explicit",
            notificationsEnabled: false
        )
        
        let encoded = try JSONEncoder().encode(insert)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["notification_tone"] as? String == "explicit")
        #expect(json?["notifications_enabled"] as? Bool == false)
    }
}

@Suite("Supabase Couple Model Tests")
struct SupabaseCoupleModelTests {
    
    @Test("Couple has required fields")
    func coupleRequiredFields() {
        let id = UUID()
        let womanId = UUID()
        let couple = Couple(
            id: id,
            womanId: womanId,
            partnerId: nil,
            inviteCode: "ABC123",
            isLinked: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(couple.id == id)
        #expect(couple.womanId == womanId)
        #expect(couple.partnerId == nil)
        #expect(couple.inviteCode == "ABC123")
        #expect(couple.isLinked == false)
    }
    
    @Test("Couple becomes linked with partner")
    func coupleLinking() {
        let partnerId = UUID()
        var couple = Couple(
            id: UUID(),
            womanId: UUID(),
            partnerId: nil,
            inviteCode: "XYZ789",
            isLinked: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        couple.partnerId = partnerId
        couple.isLinked = true
        
        #expect(couple.partnerId == partnerId)
        #expect(couple.isLinked == true)
    }
}
