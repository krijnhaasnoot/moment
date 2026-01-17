//
//  SupabaseService.swift
//  Moment
//
//  Supabase backend integration for authentication, data sync, and real-time updates
//

import Foundation
import Supabase

// MARK: - Configuration

enum SupabaseConfig {
    static let url = URL(string: "https://tymvdvoyfjpxcesjwbgg.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5bXZkdm95ZmpweGNlc2p3YmdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1Mzg4MTMsImV4cCI6MjA4NDExNDgxM30.KQc2vjaEBb300AXk1fUsa_79PjtiRqAEOLDOUEATNJE"
}

// MARK: - Supabase Service

@Observable
final class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    // Current session state
    var currentUser: User?
    var currentSession: Session?
    var isAuthenticated: Bool { currentSession != nil }
    
    // Real-time channels
    private var coupleChannel: RealtimeChannelV2?
    private var cycleChannel: RealtimeChannelV2?
    
    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    storage: KeychainLocalStorage(),
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        
        Task {
            await setupAuthListener()
        }
    }
    
    // MARK: - Auth Listener
    
    private func setupAuthListener() async {
        for await (event, session) in client.auth.authStateChanges {
            await MainActor.run {
                self.currentSession = session
                
                switch event {
                case .signedIn:
                    print("✅ User signed in: \(session?.user.id.uuidString ?? "unknown")")
                case .signedOut:
                    print("👋 User signed out")
                    self.currentUser = nil
                case .userUpdated:
                    print("🔄 User updated")
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Sign up with email and password
    func signUp(email: String, password: String, name: String, role: UserRole) async throws -> Profile {
        // Create auth user
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        let userId = authResponse.user.id
        
        // Create profile (trigger will auto-create couple for woman)
        let profile = ProfileInsert(
            id: userId,
            name: name,
            role: role.rawValue,
            notificationTone: "discreet",
            notificationsEnabled: true
        )
        
        let createdProfile: Profile = try await client
            .from("profiles")
            .insert(profile)
            .select()
            .single()
            .execute()
            .value
        
        return createdProfile
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> Profile {
        try await client.auth.signIn(email: email, password: password)
        
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.authFailed("Failed to sign in")
        }
        
        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    /// Sign out
    func signOut() async throws {
        try await client.auth.signOut()
        await unsubscribeFromRealtime()
    }
    
    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws -> Profile {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.authFailed("Failed to sign in with Apple")
        }
        
        // Check if profile exists
        let existingProfile: Profile? = try? await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        if let profile = existingProfile {
            return profile
        }
        
        // Profile will need to be created during onboarding
        throw SupabaseError.profileNotFound
    }
    
    // MARK: - Profile Management
    
    /// Get current user's profile (with retry)
    func getProfile() async throws -> Profile {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        return try await NetworkService.shared.withRetry {
            let profile: Profile = try await self.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            return profile
        }
    }
    
    /// Get profile by ID (for fetching partner's name)
    func getProfileById(_ id: UUID) async throws -> Profile {
        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    /// Get connected partner's name
    func getPartnerName() async throws -> String? {
        guard let couple = try await getCouple(), couple.isLinked else {
            return nil
        }
        
        guard let currentUserId = client.auth.currentUser?.id else {
            return nil
        }
        
        // Determine partner's ID based on current user's role
        let partnerId: UUID
        if currentUserId == couple.womanId {
            // Current user is woman, get partner's name
            guard let pid = couple.partnerId else { return nil }
            partnerId = pid
        } else {
            // Current user is partner, get woman's name
            partnerId = couple.womanId
        }
        
        let partnerProfile = try await getProfileById(partnerId)
        return partnerProfile.name
    }
    
    /// Update profile
    func updateProfile(_ updates: ProfileUpdate) async throws -> Profile {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let profile: Profile = try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return profile
    }
    
    /// Update push notification token
    func updatePushToken(_ token: String) async throws {
        guard let userId = client.auth.currentUser?.id else { return }
        
        try await client
            .from("profiles")
            .update(["push_token": token])
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - Couple Management
    
    /// Get couple for current user (with retry)
    func getCouple() async throws -> Couple? {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        return try await NetworkService.shared.withRetry {
            // Simple struct to just get couple_id
            struct ProfileCoupleId: Codable {
                let coupleId: UUID?
                enum CodingKeys: String, CodingKey {
                    case coupleId = "couple_id"
                }
            }
            
            let profile: ProfileCoupleId = try await self.client
                .from("profiles")
                .select("couple_id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else { return nil }
            
            let couple: Couple = try await self.client
                .from("couples")
                .select()
                .eq("id", value: coupleId.uuidString)
                .single()
                .execute()
                .value
            
            return couple
        }
    }
    
    /// Delete all user data from Supabase (for reset)
    func deleteUserData() async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🗑️ Deleting user data for: \(userId)")
        
        // Get the couple first
        if let couple = try? await getCouple() {
            // Delete cycles (cycle_days are deleted via CASCADE)
            try await client
                .from("cycles")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("✅ Deleted cycles")
            
            // If user is the woman (owner), delete the couple
            if couple.womanId == userId {
                try await client
                    .from("couples")
                    .delete()
                    .eq("id", value: couple.id.uuidString)
                    .execute()
                print("✅ Deleted couple")
            } else {
                // If user is partner, just unlink from the couple
                struct CoupleUnlink: Encodable {
                    let partner_id: String?
                    let is_linked: Bool
                }
                
                try await client
                    .from("couples")
                    .update(CoupleUnlink(partner_id: nil, is_linked: false))
                    .eq("id", value: couple.id.uuidString)
                    .execute()
                print("✅ Unlinked from couple")
            }
        }
        
        // Clear couple_id from profile (don't delete profile, keep auth)
        struct ProfileReset: Encodable {
            let couple_id: String?
            let name: String?
        }
        
        try await client
            .from("profiles")
            .update(ProfileReset(couple_id: nil, name: nil))
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Reset profile")
    }
    
    /// Join couple with invite code
    func joinCouple(inviteCode: String) async throws -> JoinCoupleResult {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let uppercasedCode = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Find the couple with the invite code
        let couples: [Couple] = try await client
            .from("couples")
            .select()
            .eq("invite_code", value: uppercasedCode)
            .execute()
            .value
        
        guard let couple = couples.first else {
            return JoinCoupleResult(success: false, error: "Invalid invite code", coupleId: nil)
        }
        
        if couple.isLinked {
            return JoinCoupleResult(success: false, error: "This couple is already linked", coupleId: nil)
        }
        
        // Update the couple to link the partner
        struct CoupleUpdate: Encodable {
            let partner_id: String
            let is_linked: Bool
        }
        
        try await client
            .from("couples")
            .update(CoupleUpdate(partner_id: userId.uuidString, is_linked: true))
            .eq("id", value: couple.id.uuidString)
            .execute()
        
        // Update partner's profile with couple_id
        struct ProfileCoupleUpdate: Encodable {
            let couple_id: String
        }
        
        try await client
            .from("profiles")
            .update(ProfileCoupleUpdate(couple_id: couple.id.uuidString))
            .eq("id", value: userId.uuidString)
            .execute()
        
        return JoinCoupleResult(success: true, error: nil, coupleId: couple.id)
    }
    
    // MARK: - Cycle Management
    
    /// Get active cycle
    func getActiveCycle() async throws -> CycleRecord? {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let cycle: CycleRecord? = try await client
            .from("cycles")
            .select("*, cycle_days(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .single()
            .execute()
            .value
        
        return cycle
    }
    
    /// Get partner's active cycle (limited view, with retry)
    func getPartnerCycle() async throws -> CycleRecord? {
        print("🔍 Getting partner cycle...")
        
        guard let couple = try await getCouple() else {
            print("⚠️ No couple found for partner")
            return nil
        }
        
        print("📋 Couple found: \(couple.id), isLinked: \(couple.isLinked), womanId: \(couple.womanId)")
        
        guard couple.isLinked else {
            print("⚠️ Couple is not linked yet")
            return nil
        }
        
        return try await NetworkService.shared.withRetry {
            print("🔄 Fetching cycle for couple_id: \(couple.id)")
            
            do {
                let cycle: CycleRecord = try await self.client
                    .from("cycles")
                    .select("*, cycle_days(id, cycle_id, date, fertility_level, is_menstruation, lh_test_result, had_intimacy)")
                    .eq("couple_id", value: couple.id.uuidString)
                    .eq("is_active", value: true)
                    .single()
                    .execute()
                    .value
                
                print("✅ Found cycle: \(cycle.id)")
                return cycle
            } catch {
                print("⚠️ No cycle found for couple_id \(couple.id): \(error)")
                
                // Try fetching by woman_id instead (fallback)
                print("🔄 Trying to fetch by woman_id: \(couple.womanId)")
                do {
                    let cycle: CycleRecord = try await self.client
                        .from("cycles")
                        .select("*, cycle_days(id, cycle_id, date, fertility_level, is_menstruation, lh_test_result, had_intimacy)")
                        .eq("user_id", value: couple.womanId.uuidString)
                        .eq("is_active", value: true)
                        .single()
                        .execute()
                        .value
                    
                    print("✅ Found cycle by woman_id: \(cycle.id), couple_id in cycle: \(cycle.coupleId?.uuidString ?? "nil")")
                    
                    // If cycle doesn't have couple_id, update it
                    if cycle.coupleId == nil {
                        print("⚠️ Cycle missing couple_id, updating...")
                        try await self.updateCycleCoupleId(cycleId: cycle.id, coupleId: couple.id)
                        
                        // Fetch again with updated data
                        let updatedCycle: CycleRecord = try await self.client
                            .from("cycles")
                            .select("*, cycle_days(id, cycle_id, date, fertility_level, is_menstruation, lh_test_result, had_intimacy)")
                            .eq("id", value: cycle.id.uuidString)
                            .single()
                            .execute()
                            .value
                        return updatedCycle
                    }
                    
                    return cycle
                } catch {
                    print("❌ No cycle found by woman_id either: \(error)")
                    return nil
                }
            }
        }
    }
    
    /// Create new cycle
    func createCycle(startDate: Date, cycleLength: Int = 28) async throws -> CycleRecord {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let couple = try await getCouple()
        
        // Deactivate previous cycles
        struct CycleDeactivate: Encodable {
            let is_active: Bool
            let end_date: String
        }
        let deactivateData = CycleDeactivate(
            is_active: false,
            end_date: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("cycles")
            .update(deactivateData)
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .execute()
        
        // Create new cycle
        let newCycle = CycleInsert(
            userId: userId,
            coupleId: couple?.id,
            startDate: startDate,
            cycleLength: cycleLength,
            isActive: true
        )
        
        let cycle: CycleRecord = try await client
            .from("cycles")
            .insert(newCycle)
            .select()
            .single()
            .execute()
            .value
        
        // Generate cycle days
        try await generateCycleDays(for: cycle)
        
        // Fetch complete cycle with days
        return try await getActiveCycle()!
    }
    
    /// Generate cycle days for a cycle
    private func generateCycleDays(for cycle: CycleRecord) async throws {
        let calendar = Calendar.current
        var days: [CycleDayInsert] = []
        
        // Ensure valid cycle length
        let cycleLength = max(1, cycle.cycleLength)
        
        let ovulationDay = max(1, cycleLength - 14)
        let fertileStart = max(1, ovulationDay - 5)
        let fertileEnd = ovulationDay + 1
        
        for dayOffset in 0..<cycleLength {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycle.startDate) else { continue }
            let dayNumber = dayOffset + 1
            
            var fertilityLevel = "low"
            let isMenstruation = dayNumber <= 5
            
            if dayNumber >= fertileStart && dayNumber <= fertileEnd {
                if dayNumber == ovulationDay || dayNumber == ovulationDay - 1 {
                    fertilityLevel = "peak"
                } else {
                    fertilityLevel = "high"
                }
            }
            
            days.append(CycleDayInsert(
                cycleId: cycle.id,
                date: date,
                fertilityLevel: fertilityLevel,
                isMenstruation: isMenstruation
            ))
        }
        
        try await client
            .from("cycle_days")
            .insert(days)
            .execute()
    }
    
    /// Update cycle's couple_id if missing
    func updateCycleCoupleId(cycleId: UUID, coupleId: UUID) async throws {
        struct CycleUpdate: Encodable {
            let couple_id: String
        }
        
        try await client
            .from("cycles")
            .update(CycleUpdate(couple_id: coupleId.uuidString))
            .eq("id", value: cycleId.uuidString)
            .execute()
        
        print("✅ Updated cycle \(cycleId) with couple_id \(coupleId)")
    }
    
    /// Ensure active cycle has couple_id set
    func ensureCycleHasCoupleId() async throws {
        guard client.auth.currentUser != nil else {
            throw SupabaseError.notAuthenticated
        }
        
        // Get active cycle
        guard let cycle = try await getActiveCycle() else {
            print("ℹ️ No active cycle to update")
            return
        }
        
        // If couple_id is already set, nothing to do
        if cycle.coupleId != nil {
            print("ℹ️ Cycle already has couple_id")
            return
        }
        
        // Get couple
        guard let couple = try await getCouple() else {
            print("ℹ️ No couple found for user")
            return
        }
        
        // Update cycle with couple_id
        try await updateCycleCoupleId(cycleId: cycle.id, coupleId: couple.id)
    }
    
    /// Log LH test result
    func logLHTest(cycleId: UUID, date: Date, result: String) async throws -> CycleDayRecord {
        let dateString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        
        var updates: [String: AnyJSON] = [
            "lh_test_result": .string(result),
            "lh_test_logged_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        // If positive, mark as peak fertility
        if result == "positive" {
            updates["fertility_level"] = .string("peak")
        }
        
        let cycleDay: CycleDayRecord = try await client
            .from("cycle_days")
            .update(updates)
            .eq("cycle_id", value: cycleId.uuidString)
            .eq("date", value: dateString)
            .select()
            .single()
            .execute()
            .value
        
        // If positive, trigger notification to partner
        if result == "positive" {
            try await sendLHPositiveNotification()
        }
        
        return cycleDay
    }
    
    /// Log intimacy event for a date
    func logIntimacy(date: Date, hadIntimacy: Bool) async throws {
        // Get the user's active cycle, or partner's cycle
        guard client.auth.currentUser != nil else {
            throw SupabaseError.notAuthenticated
        }
        
        // First try to get user's own active cycle
        var cycleId: UUID?
        
        if let cycle = try? await getActiveCycle() {
            cycleId = cycle.id
        } else if let couple = try? await getCouple(), couple.isLinked {
            // Partner - get the woman's cycle
            let cycle: CycleRecord? = try await client
                .from("cycles")
                .select()
                .eq("user_id", value: couple.womanId.uuidString)
                .eq("is_active", value: true)
                .single()
                .execute()
                .value
            cycleId = cycle?.id
        }
        
        guard let cycleId = cycleId else {
            print("⚠️ No cycle found for logging intimacy")
            return
        }
        
        let dateString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        
        struct IntimacyUpdate: Encodable {
            let had_intimacy: Bool
        }
        
        try await client
            .from("cycle_days")
            .update(IntimacyUpdate(had_intimacy: hadIntimacy))
            .eq("cycle_id", value: cycleId.uuidString)
            .eq("date", value: dateString)
            .execute()
        
        print("✅ Logged intimacy for \(dateString): \(hadIntimacy)")
    }
    
    // MARK: - Push Notifications
    
    /// Send push notification to a specific user
    func sendPushNotification(to userId: UUID, title: String, body: String, data: [String: String]? = nil) async throws {
        struct PushPayload: Encodable {
            let userId: String
            let title: String
            let body: String
            let data: [String: String]?
        }
        
        let payload = PushPayload(
            userId: userId.uuidString,
            title: title,
            body: body,
            data: data
        )
        
        try await client.functions.invoke(
            "send-push-notification",
            options: .init(method: .post, body: payload)
        )
    }
    
    /// Send LH positive notification to partner
    func sendLHPositiveNotification() async throws {
        guard let couple = try await getCouple(), couple.isLinked, let partnerId = couple.partnerId else {
            return
        }
        
        // Get woman's notification tone preference
        let profile = try await getProfile()
        let tone = profile.notificationTone
        
        let title: String
        let body: String
        
        if tone == "explicit" {
            title = "Peak Fertility Today"
            body = "Your partner's LH test is positive - best timing for conception"
        } else {
            title = "Important Moment"
            body = "Your partner wants to connect with you"
        }
        
        try await sendPushNotification(to: partnerId, title: title, body: body, data: ["type": "lh_positive"])
    }
    
    /// Send daily fertility notification to partner
    func sendDailyFertilityNotification(fertilityLevel: String) async throws {
        guard let couple = try await getCouple(), couple.isLinked, let partnerId = couple.partnerId else {
            return
        }
        
        // Get woman's notification tone preference
        let profile = try await getProfile()
        let tone = profile.notificationTone
        
        let title: String
        let body: String
        
        switch fertilityLevel {
        case "peak":
            title = tone == "explicit" ? "Peak Fertility" : "Special Moment"
            body = tone == "explicit" ? "Best timing today" : "Time to connect"
        case "high":
            title = tone == "explicit" ? "High Fertility" : "Good Timing"
            body = tone == "explicit" ? "Good timing today" : "Your partner may want to connect"
        default:
            return // Don't send notifications for low fertility
        }
        
        try await sendPushNotification(to: partnerId, title: title, body: body, data: ["type": "daily_fertility"])
    }
    
    // MARK: - Real-time Subscriptions
    
    /// Subscribe to couple changes (for partner linking)
    func subscribeToCouple(coupleId: UUID, onChange: @escaping (Couple) -> Void) async {
        coupleChannel = client.realtimeV2.channel("couple_\(coupleId.uuidString)")
        
        let changes = coupleChannel!.postgresChange(
            UpdateAction.self,
            table: "couples",
            filter: .eq("id", value: coupleId.uuidString)
        )
        
        do {
            try await coupleChannel!.subscribeWithError()
        } catch {
            print("Failed to subscribe to couple channel: \(error)")
            return
        }
        
        Task {
            for await change in changes {
                if let couple = try? change.decodeRecord(as: Couple.self, decoder: JSONDecoder()) {
                    await MainActor.run {
                        onChange(couple)
                    }
                }
            }
        }
    }
    
    /// Subscribe to cycle day changes (for real-time sync)
    func subscribeToCycleDays(cycleId: UUID, onChange: @escaping ([CycleDayRecord]) -> Void) async {
        cycleChannel = client.realtimeV2.channel("cycle_\(cycleId.uuidString)")
        
        let changes = cycleChannel!.postgresChange(
            AnyAction.self,
            table: "cycle_days",
            filter: .eq("cycle_id", value: cycleId.uuidString)
        )
        
        do {
            try await cycleChannel!.subscribeWithError()
        } catch {
            print("Failed to subscribe to cycle channel: \(error)")
            return
        }
        
        Task {
            for await _ in changes {
                // Refetch all days on any change
                if let cycle = try? await getActiveCycle() {
                    await MainActor.run {
                        onChange(cycle.cycleDays ?? [])
                    }
                }
            }
        }
    }
    
    /// Unsubscribe from all channels
    func unsubscribeFromRealtime() async {
        if let channel = coupleChannel {
            await channel.unsubscribe()
        }
        if let channel = cycleChannel {
            await channel.unsubscribe()
        }
    }
}

// MARK: - Database Models

struct Profile: Codable {
    let id: UUID
    var name: String
    var role: String
    var coupleId: UUID?
    var notificationTone: String
    var notificationsEnabled: Bool
    var pushToken: String?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, role
        case coupleId = "couple_id"
        case notificationTone = "notification_tone"
        case notificationsEnabled = "notifications_enabled"
        case pushToken = "push_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProfileInsert: Codable {
    let id: UUID
    let name: String
    let role: String
    let notificationTone: String
    let notificationsEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, role
        case notificationTone = "notification_tone"
        case notificationsEnabled = "notifications_enabled"
    }
}

struct ProfileUpdate: Codable {
    var name: String?
    var notificationTone: String?
    var notificationsEnabled: Bool?
    var pushToken: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case notificationTone = "notification_tone"
        case notificationsEnabled = "notifications_enabled"
        case pushToken = "push_token"
    }
}

struct Couple: Codable {
    let id: UUID
    let womanId: UUID
    var partnerId: UUID?
    let inviteCode: String
    var isLinked: Bool
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case womanId = "woman_id"
        case partnerId = "partner_id"
        case inviteCode = "invite_code"
        case isLinked = "is_linked"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct JoinCoupleResult: Codable {
    let success: Bool
    let error: String?
    let coupleId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case success, error
        case coupleId = "couple_id"
    }
}

struct CycleRecord: Codable {
    let id: UUID
    let userId: UUID
    let coupleId: UUID?
    let startDate: Date
    var endDate: Date?
    let cycleLength: Int
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
    var cycleDays: [CycleDayRecord]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case coupleId = "couple_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case cycleLength = "cycle_length"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case cycleDays = "cycle_days"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        coupleId = try container.decodeIfPresent(UUID.self, forKey: .coupleId)
        cycleLength = try container.decode(Int.self, forKey: .cycleLength)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        cycleDays = try container.decodeIfPresent([CycleDayRecord].self, forKey: .cycleDays)
        
        // Handle flexible date formats
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let iso8601NoFracFormatter = ISO8601DateFormatter()
        iso8601NoFracFormatter.formatOptions = [.withInternetDateTime]
        
        // Parse start_date
        let startDateString = try container.decode(String.self, forKey: .startDate)
        if let date = dateFormatter.date(from: startDateString) {
            startDate = date
        } else if let date = iso8601Formatter.date(from: startDateString) {
            startDate = date
        } else if let date = iso8601NoFracFormatter.date(from: startDateString) {
            startDate = date
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.startDate], debugDescription: "Invalid date format: \(startDateString)"))
        }
        
        // Parse end_date (optional)
        if let endDateString = try container.decodeIfPresent(String.self, forKey: .endDate) {
            if let date = dateFormatter.date(from: endDateString) {
                endDate = date
            } else if let date = iso8601Formatter.date(from: endDateString) {
                endDate = date
            } else if let date = iso8601NoFracFormatter.date(from: endDateString) {
                endDate = date
            } else {
                endDate = nil
            }
        } else {
            endDate = nil
        }
        
        // Parse created_at and updated_at (ISO8601 with timezone)
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = iso8601Formatter.date(from: createdAtString) {
            createdAt = date
        } else if let date = iso8601NoFracFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        if let date = iso8601Formatter.date(from: updatedAtString) {
            updatedAt = date
        } else if let date = iso8601NoFracFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }
}

struct CycleInsert: Codable {
    let userId: UUID
    let coupleId: UUID?
    let startDate: Date
    let cycleLength: Int
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case coupleId = "couple_id"
        case startDate = "start_date"
        case cycleLength = "cycle_length"
        case isActive = "is_active"
    }
}

struct CycleDayRecord: Codable {
    let id: UUID
    let cycleId: UUID
    let date: Date
    var fertilityLevel: String
    var isMenstruation: Bool
    var lhTestResult: String?
    var lhTestLoggedAt: Date?
    var notes: String?
    var hadIntimacy: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case cycleId = "cycle_id"
        case date
        case fertilityLevel = "fertility_level"
        case isMenstruation = "is_menstruation"
        case lhTestResult = "lh_test_result"
        case lhTestLoggedAt = "lh_test_logged_at"
        case notes
        case hadIntimacy = "had_intimacy"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        cycleId = try container.decode(UUID.self, forKey: .cycleId)
        fertilityLevel = try container.decode(String.self, forKey: .fertilityLevel)
        isMenstruation = try container.decodeIfPresent(Bool.self, forKey: .isMenstruation) ?? false
        lhTestResult = try container.decodeIfPresent(String.self, forKey: .lhTestResult)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        hadIntimacy = try container.decodeIfPresent(Bool.self, forKey: .hadIntimacy)
        
        // Handle flexible date formats
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse date
        let dateString = try container.decode(String.self, forKey: .date)
        if let parsedDate = dateFormatter.date(from: dateString) {
            date = parsedDate
        } else if let parsedDate = iso8601Formatter.date(from: dateString) {
            date = parsedDate
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.date], debugDescription: "Invalid date format: \(dateString)"))
        }
        
        // Parse lhTestLoggedAt (optional)
        if let loggedAtString = try container.decodeIfPresent(String.self, forKey: .lhTestLoggedAt) {
            if let parsedDate = iso8601Formatter.date(from: loggedAtString) {
                lhTestLoggedAt = parsedDate
            } else {
                lhTestLoggedAt = nil
            }
        } else {
            lhTestLoggedAt = nil
        }
    }
}

struct CycleDayInsert: Codable {
    let cycleId: UUID
    let date: Date
    let fertilityLevel: String
    let isMenstruation: Bool
    
    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case date
        case fertilityLevel = "fertility_level"
        case isMenstruation = "is_menstruation"
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case authFailed(String)
    case profileNotFound
    case coupleNotFound
    case invalidInviteCode
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .authFailed(let message):
            return message
        case .profileNotFound:
            return "Profile not found"
        case .coupleNotFound:
            return "Couple not found"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
