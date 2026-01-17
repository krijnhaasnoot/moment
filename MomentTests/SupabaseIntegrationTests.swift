//
//  SupabaseIntegrationTests.swift
//  MomentTests
//
//  Integration tests for Supabase backend
//  Note: These tests require a valid Supabase connection
//

import Testing
import Foundation
@testable import Moment

@Suite("Supabase Model Encoding Tests")
struct SupabaseModelEncodingTests {
    
    // MARK: - Profile Encoding
    
    @Test("Profile encodes correctly for Supabase")
    func profileEncoding() throws {
        let profile = ProfileInsert(
            id: UUID(),
            name: "Sarah",
            role: "woman",
            notificationTone: "discreet",
            notificationsEnabled: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["name"] as? String == "Sarah")
        #expect(json["role"] as? String == "woman")
        #expect(json["notification_tone"] as? String == "discreet")
        #expect(json["notifications_enabled"] as? Bool == true)
    }
    
    @Test("Profile decodes correctly from Supabase")
    func profileDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Sarah",
            "role": "woman",
            "couple_id": "660e8400-e29b-41d4-a716-446655440000",
            "notification_tone": "explicit",
            "notifications_enabled": false,
            "push_token": "abc123",
            "created_at": "2026-01-16T10:00:00Z",
            "updated_at": "2026-01-16T10:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let profile = try decoder.decode(Profile.self, from: json.data(using: .utf8)!)
        
        #expect(profile.name == "Sarah")
        #expect(profile.role == "woman")
        #expect(profile.notificationTone == "explicit")
        #expect(profile.notificationsEnabled == false)
        #expect(profile.pushToken == "abc123")
    }
    
    // MARK: - Couple Encoding
    
    @Test("Couple decodes correctly from Supabase")
    func coupleDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "woman_id": "660e8400-e29b-41d4-a716-446655440000",
            "partner_id": null,
            "invite_code": "ABC123",
            "is_linked": false,
            "created_at": "2026-01-16T10:00:00Z",
            "updated_at": "2026-01-16T10:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let couple = try decoder.decode(Couple.self, from: json.data(using: .utf8)!)
        
        #expect(couple.inviteCode == "ABC123")
        #expect(couple.isLinked == false)
        #expect(couple.partnerId == nil)
    }
    
    @Test("Linked couple decodes correctly")
    func linkedCoupleDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "woman_id": "660e8400-e29b-41d4-a716-446655440000",
            "partner_id": "770e8400-e29b-41d4-a716-446655440000",
            "invite_code": "XYZ789",
            "is_linked": true,
            "created_at": "2026-01-16T10:00:00Z",
            "updated_at": "2026-01-16T10:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let couple = try decoder.decode(Couple.self, from: json.data(using: .utf8)!)
        
        #expect(couple.isLinked == true)
        #expect(couple.partnerId != nil)
    }
    
    // MARK: - Cycle Encoding
    
    @Test("Cycle insert encodes correctly")
    func cycleInsertEncoding() throws {
        let cycle = CycleInsert(
            userId: UUID(),
            coupleId: UUID(),
            startDate: Date(),
            cycleLength: 28,
            isActive: true
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(cycle)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["cycle_length"] as? Int == 28)
        #expect(json["is_active"] as? Bool == true)
    }
    
    // MARK: - Cycle Day Encoding
    
    @Test("Cycle day insert encodes correctly")
    func cycleDayInsertEncoding() throws {
        let cycleDay = CycleDayInsert(
            cycleId: UUID(),
            date: Date(),
            fertilityLevel: "peak",
            isMenstruation: false
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(cycleDay)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["fertility_level"] as? String == "peak")
        #expect(json["is_menstruation"] as? Bool == false)
    }
    
    @Test("Cycle day record decodes correctly")
    func cycleDayRecordDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "cycle_id": "660e8400-e29b-41d4-a716-446655440000",
            "date": "2026-01-16",
            "fertility_level": "high",
            "is_menstruation": false,
            "lh_test_result": "positive",
            "lh_test_logged_at": "2026-01-16T14:30:00Z",
            "notes": null
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let day = try decoder.decode(CycleDayRecord.self, from: json.data(using: .utf8)!)
        
        #expect(day.fertilityLevel == "high")
        #expect(day.lhTestResult == "positive")
        #expect(day.isMenstruation == false)
    }
    
    // MARK: - Join Couple Result
    
    @Test("Join couple success result decodes")
    func joinCoupleSuccessDecoding() throws {
        let json = """
        {
            "success": true,
            "error": null,
            "couple_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        """
        
        let result = try JSONDecoder().decode(JoinCoupleResult.self, from: json.data(using: .utf8)!)
        
        #expect(result.success == true)
        #expect(result.error == nil)
        #expect(result.coupleId != nil)
    }
    
    @Test("Join couple error result decodes")
    func joinCoupleErrorDecoding() throws {
        let json = """
        {
            "success": false,
            "error": "Invalid invite code",
            "couple_id": null
        }
        """
        
        let result = try JSONDecoder().decode(JoinCoupleResult.self, from: json.data(using: .utf8)!)
        
        #expect(result.success == false)
        #expect(result.error == "Invalid invite code")
        #expect(result.coupleId == nil)
    }
}

@Suite("Supabase Error Tests")
struct SupabaseErrorTests {
    
    @Test("Supabase errors have descriptions")
    func errorDescriptions() {
        let errors: [SupabaseError] = [
            .notAuthenticated,
            .authFailed("Test error"),
            .profileNotFound,
            .coupleNotFound,
            .invalidInviteCode
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("Auth failed error contains message")
    func authFailedContainsMessage() {
        let error = SupabaseError.authFailed("Custom message")
        #expect(error.errorDescription == "Custom message")
    }
}
