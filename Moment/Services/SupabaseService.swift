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

// MARK: - Date Formatting Helpers

/// Date-only formatter for database DATE columns (yyyy-MM-dd)
/// IMPORTANT: Always use this for cycle_days.date, cycles.start_date, cycles.end_date
/// Using ISO8601DateFormatter causes timezone issues (dates shift by 1 day)
private let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .current  // Use local timezone for date-only fields
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

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
        } else if currentUserId == couple.partnerId {
            // Current user is partner, get woman's name
            guard let wid = couple.womanId else { return nil }
            partnerId = wid
        } else {
            return nil
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
    
    // MARK: - Profile Photo
    
    /// Upload profile photo to Supabase Storage
    func uploadProfilePhoto(_ imageData: Data) async throws -> String {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Use lowercase UUID to match PostgreSQL's auth.uid()::text
        let filePath = "\(userId.uuidString.lowercased())/profile.jpg"
        
        // Upload to Storage
        try await client.storage
            .from("profile-photos")
            .upload(
                filePath,
                data: imageData,
                options: .init(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
        
        // Get signed URL (valid for 1 year)
        let signedUrl = try await client.storage
            .from("profile-photos")
            .createSignedURL(path: filePath, expiresIn: 31536000)  // 1 year
        
        let urlString = signedUrl.absoluteString
        
        // Update profile with URL
        let update = ProfileUpdate(profilePhotoUrl: urlString)
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Uploaded profile photo: \(urlString)")
        return urlString
    }
    
    /// Delete profile photo from Supabase Storage
    func deleteProfilePhoto() async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Use lowercase UUID to match PostgreSQL's auth.uid()::text
        let filePath = "\(userId.uuidString.lowercased())/profile.jpg"
        
        // Delete from Storage
        try await client.storage
            .from("profile-photos")
            .remove(paths: [filePath])
        
        // Clear URL from profile
        try await client
            .from("profiles")
            .update(["profile_photo_url": AnyJSON.null])
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Deleted profile photo")
    }
    
    /// Get partner's profile (including photo URL)
    func getPartnerProfile() async throws -> Profile? {
        guard let couple = try await getCouple(), couple.isLinked else {
            return nil
        }
        
        guard let currentUserId = client.auth.currentUser?.id else {
            return nil
        }
        
        // Determine partner's ID based on current user's role
        let partnerId: UUID
        if currentUserId == couple.womanId {
            guard let pid = couple.partnerId else { return nil }
            partnerId = pid
        } else if currentUserId == couple.partnerId {
            guard let wid = couple.womanId else { return nil }
            partnerId = wid
        } else {
            return nil
        }
        
        return try await getProfileById(partnerId)
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
    
    /// Ensure a couple exists for the current user.
    /// If no couple exists, creates one and returns it.
    func ensureCouple() async throws -> Couple {
        // First try to get existing couple
        if let existingCouple = try await getCouple() {
            return existingCouple
        }
        
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Get user's role
        let profile = try await getProfile()
        let isWoman = profile.role == "woman"
        
        print("📝 Creating couple for user \(userId) with role \(profile.role)")
        
        // Generate invite code
        let inviteCode = generateInviteCode()
        
        // Create couple
        struct CoupleInsert: Encodable {
            let woman_id: String?
            let partner_id: String?
            let created_by: String
            let invite_code: String
        }
        
        let insert = CoupleInsert(
            woman_id: isWoman ? userId.uuidString : nil,
            partner_id: isWoman ? nil : userId.uuidString,
            created_by: userId.uuidString,
            invite_code: inviteCode
        )
        
        let couple: Couple = try await client
            .from("couples")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        
        // Update profile with couple_id
        struct ProfileCoupleUpdate: Encodable {
            let couple_id: String
        }
        
        try await client
            .from("profiles")
            .update(ProfileCoupleUpdate(couple_id: couple.id.uuidString))
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Created couple with invite code: \(inviteCode)")
        
        return couple
    }
    
    /// Generate a random 6-character invite code
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    /// Disconnect from partner - removes the partner link but keeps the couple record
    func disconnectCouple() async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        guard let couple = try await getCouple() else {
            throw SupabaseError.syncFailed("No couple found")
        }
        
        print("🔗 Disconnecting couple: \(couple.id)")
        
        let isWoman = couple.womanId == userId
        
        // Generate a new invite code for future connection
        let newInviteCode = generateInviteCode()
        
        struct CoupleDisconnect: Encodable {
            let woman_id: String?
            let partner_id: String?
            let invite_code: String
        }
        
        // Keep the current user, remove the other partner
        let update = CoupleDisconnect(
            woman_id: isWoman ? userId.uuidString : nil,
            partner_id: isWoman ? nil : userId.uuidString,
            invite_code: newInviteCode
        )
        
        try await client
            .from("couples")
            .update(update)
            .eq("id", value: couple.id.uuidString)
            .execute()
        
        print("✅ Disconnected from partner, new invite code: \(newInviteCode)")
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
            
            // Determine if user is the creator/owner of the couple
            let isWoman = couple.womanId == userId
            let isPartnerCreator = couple.partnerId == userId && couple.womanId == nil
            
            if isWoman || isPartnerCreator {
                // User created the couple - delete it entirely
                try await client
                    .from("couples")
                    .delete()
                    .eq("id", value: couple.id.uuidString)
                    .execute()
                print("✅ Deleted couple")
            } else {
                // User joined the couple - just unlink
                if couple.womanId == userId {
                    struct WomanUnlink: Encodable {
                        let woman_id: String?
                        let is_linked: Bool
                    }
                    try await client
                        .from("couples")
                        .update(WomanUnlink(woman_id: nil, is_linked: false))
                        .eq("id", value: couple.id.uuidString)
                        .execute()
                } else {
                    struct PartnerUnlink: Encodable {
                        let partner_id: String?
                        let is_linked: Bool
                    }
                    try await client
                        .from("couples")
                        .update(PartnerUnlink(partner_id: nil, is_linked: false))
                        .eq("id", value: couple.id.uuidString)
                        .execute()
                }
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
        
        print("🔍 JOIN DEBUG - Couple found:")
        print("   - couple.id: \(couple.id)")
        print("   - couple.womanId: \(couple.womanId?.uuidString ?? "nil")")
        print("   - couple.partnerId: \(couple.partnerId?.uuidString ?? "nil")")
        print("   - couple.isLinked: \(couple.isLinked)")
        
        if couple.isLinked {
            return JoinCoupleResult(success: false, error: "This couple is already linked", coupleId: nil)
        }
        
        // Get the joiner's profile to determine their role
        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        print("🔍 JOIN DEBUG - Joiner profile:")
        print("   - profile.id: \(profile.id)")
        print("   - profile.name: \(profile.name)")
        print("   - profile.role: \(profile.role)")
        print("   - profile.coupleId: \(profile.coupleId?.uuidString ?? "nil")")
        
        // Role-agnostic joining: fill the appropriate slot based on joiner's role
        // If couple is NOT linked yet, we can overwrite previous incomplete attempts
        print("🔍 JOIN DEBUG - Checking conditions:")
        print("   - couple.womanId: \(couple.womanId?.uuidString ?? "nil")")
        print("   - couple.partnerId: \(couple.partnerId?.uuidString ?? "nil")")
        print("   - couple.isLinked: \(couple.isLinked)")
        print("   - profile.role: \(profile.role)")
        
        if profile.role == "woman" {
            // Joiner is woman - check if woman slot is available OR couple not yet linked (can overwrite)
            if couple.womanId == nil || !couple.isLinked {
                struct WomanJoinUpdate: Encodable {
                    let woman_id: String
                    let is_linked: Bool
                }
                
                // Check if there's a partner to link with
                let willBeLinked = couple.partnerId != nil
                
                try await client
                    .from("couples")
                    .update(WomanJoinUpdate(woman_id: userId.uuidString, is_linked: willBeLinked))
                    .eq("id", value: couple.id.uuidString)
                    .execute()
                
                print("✅ Woman joined couple, is_linked: \(willBeLinked)")
            } else {
                // Woman slot taken AND couple is already linked
                return JoinCoupleResult(success: false, error: "This couple is already fully connected.", coupleId: nil)
            }
        } else if profile.role == "partner" {
            // Joiner is partner - check if partner slot is available OR couple not yet linked (can overwrite)
            if couple.partnerId == nil || !couple.isLinked {
                struct PartnerJoinUpdate: Encodable {
                    let partner_id: String
                    let is_linked: Bool
                }
                
                // Check if there's a woman to link with
                let willBeLinked = couple.womanId != nil
                
                try await client
                    .from("couples")
                    .update(PartnerJoinUpdate(partner_id: userId.uuidString, is_linked: willBeLinked))
                    .eq("id", value: couple.id.uuidString)
                    .execute()
                
                print("✅ Partner joined couple, is_linked: \(willBeLinked)")
            } else {
                // Partner slot taken AND couple is already linked
                return JoinCoupleResult(success: false, error: "This couple is already fully connected.", coupleId: nil)
            }
        } else {
            return JoinCoupleResult(success: false, error: "Unknown role: \(profile.role)", coupleId: nil)
        }
        
        // Clean up joiner's old couple if they had one (from a previous incomplete onboarding)
        if let oldCoupleId = profile.coupleId, oldCoupleId != couple.id {
            print("🧹 Cleaning up joiner's old couple: \(oldCoupleId)")
            
            // Check if old couple is linked - if not, delete it
            let oldCouples: [Couple] = try await client
                .from("couples")
                .select()
                .eq("id", value: oldCoupleId.uuidString)
                .execute()
                .value
            
            if let oldCouple = oldCouples.first, !oldCouple.isLinked {
                // Delete the orphan couple
                try await client
                    .from("couples")
                    .delete()
                    .eq("id", value: oldCoupleId.uuidString)
                    .execute()
                print("✅ Deleted orphan couple")
            }
        }
        
        // Update joiner's profile with couple_id
        struct ProfileCoupleUpdate: Encodable {
            let couple_id: String
        }
        
        try await client
            .from("profiles")
            .update(ProfileCoupleUpdate(couple_id: couple.id.uuidString))
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Updated joiner's profile with new couple_id: \(couple.id)")
        
        // Sync couple_id to any existing cycles (for both woman and partner joining scenarios)
        // This ensures the partner can see the cycle data immediately
        if let womanId = couple.womanId ?? (profile.role == "woman" ? userId : nil) {
            print("🔄 Syncing couple_id to woman's cycles...")
            struct CycleCoupleUpdate: Encodable {
                let couple_id: String
            }
            
            _ = try? await client
                .from("cycles")
                .update(CycleCoupleUpdate(couple_id: couple.id.uuidString))
                .eq("user_id", value: womanId.uuidString)
                .is("couple_id", value: nil)
                .execute()
            
            print("✅ Synced couple_id to woman's cycles")
        }
        
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
        
        print("📋 Couple found: \(couple.id), isLinked: \(couple.isLinked), womanId: \(couple.womanId?.uuidString ?? "nil")")
        
        guard couple.isLinked else {
            print("⚠️ Couple is not linked yet")
            return nil
        }
        
        guard let womanId = couple.womanId else {
            print("⚠️ No woman linked to couple yet")
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
                print("🔄 Trying to fetch by woman_id: \(womanId)")
                do {
                    let cycle: CycleRecord = try await self.client
                        .from("cycles")
                        .select("*, cycle_days(id, cycle_id, date, fertility_level, is_menstruation, lh_test_result, had_intimacy)")
                        .eq("user_id", value: womanId.uuidString)
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
    func createCycle(startDate: Date, cycleLength: Int = 28, lutealLength: Int = 14) async throws -> CycleRecord {
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
            end_date: dateOnlyFormatter.string(from: Date())
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
        
        // Generate cycle days using personalized luteal length
        try await generateCycleDays(for: cycle, lutealLength: lutealLength)
        
        // Fetch complete cycle with days
        guard let completeCycle = try await getActiveCycle() else {
            throw SupabaseError.syncFailed("Failed to retrieve created cycle")
        }
        return completeCycle
    }
    
    /// Update the start date of an existing cycle
    /// This will recalculate all cycle days based on the new start date
    func updateCycleStartDate(cycleId: UUID, newStartDate: Date) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        print("📅 Updating cycle \(cycleId) start date to \(newStartDate)")
        
        // Get current cycle to preserve cycle length
        let currentCycle: CycleRecord = try await client
            .from("cycles")
            .select()
            .eq("id", value: cycleId.uuidString)
            .single()
            .execute()
            .value
        
        // Delete existing cycle days
        try await client
            .from("cycle_days")
            .delete()
            .eq("cycle_id", value: cycleId.uuidString)
            .execute()
        
        // Update cycle start date
        struct CycleUpdate: Encodable {
            let start_date: String
        }
        
        try await client
            .from("cycles")
            .update(CycleUpdate(start_date: dateOnlyFormatter.string(from: newStartDate)))
            .eq("id", value: cycleId.uuidString)
            .execute()
        
        // Regenerate cycle days with new start date
        let updatedCycle = CycleRecord(
            id: currentCycle.id,
            userId: currentCycle.userId,
            coupleId: currentCycle.coupleId,
            startDate: newStartDate,
            endDate: currentCycle.endDate,
            cycleLength: currentCycle.cycleLength,
            isActive: currentCycle.isActive,
            createdAt: currentCycle.createdAt,
            updatedAt: Date(),
            cycleDays: nil
        )
        
        // Get user's personalized luteal length
        let profile = try await getProfile()
        let lutealLength = profile.averageLutealLength
        
        try await generateCycleDays(for: updatedCycle, lutealLength: lutealLength)
        
        print("✅ Cycle start date updated and days regenerated")
    }
    
    /// Generate cycle days for a cycle using personalized luteal phase length
    /// - Parameters:
    ///   - cycle: The cycle record to generate days for
    ///   - lutealLength: Personalized luteal phase length (default 14 if no learning data)
    private func generateCycleDays(for cycle: CycleRecord, lutealLength: Int = 14) async throws {
        let calendar = Calendar.current
        var days: [CycleDayInsert] = []
        
        // Ensure valid cycle length
        let cycleLength = max(1, cycle.cycleLength)
        
        // Use personalized luteal length for ovulation estimation
        // Ovulation occurs approximately lutealLength days before the next period
        let safeLutealLength = max(8, min(lutealLength, 18))  // Clamp to physiological range
        let ovulationDay = max(1, cycleLength - safeLutealLength)
        let fertileStart = max(1, ovulationDay - 5)
        let fertileEnd = min(cycleLength, ovulationDay + 1)
        
        for dayOffset in 0..<cycleLength {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycle.startDate) else { continue }
            let dayNumber = dayOffset + 1
            
            var fertilityLevel = "low"
            let isMenstruation = dayNumber <= 5
            
            // Fertile window: 5 days before ovulation to 1 day after
            if dayNumber >= fertileStart && dayNumber <= fertileEnd {
                // Peak: ovulation day and day before (highest probability)
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
    
    /// Update profile's luteal learning data after a cycle with LH data completes
    func updateLutealLearning(averageLutealLength: Int, lutealSamples: Int) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let update = ProfileUpdate(
            averageLutealLength: averageLutealLength,
            lutealSamples: lutealSamples
        )
        
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Updated luteal learning: avg=\(averageLutealLength), samples=\(lutealSamples)")
    }
    
    /// Get current user's luteal learning data
    func getLutealLearning() async throws -> (averageLutealLength: Int, lutealSamples: Int) {
        guard let userId = client.auth.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        return try await getLutealLearning(for: userId)
    }
    
    /// Get luteal learning data for a specific user (used by partners to get woman's data)
    func getLutealLearning(for userId: UUID) async throws -> (averageLutealLength: Int, lutealSamples: Int) {
        struct LutealData: Codable {
            let averageLutealLength: Int
            let lutealSamples: Int
            
            enum CodingKeys: String, CodingKey {
                case averageLutealLength = "average_luteal_length"
                case lutealSamples = "luteal_samples"
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                averageLutealLength = try container.decodeIfPresent(Int.self, forKey: .averageLutealLength) ?? 14
                lutealSamples = try container.decodeIfPresent(Int.self, forKey: .lutealSamples) ?? 0
            }
        }
        
        let data: LutealData = try await client
            .from("profiles")
            .select("average_luteal_length, luteal_samples")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return (data.averageLutealLength, data.lutealSamples)
    }
    
    /// Get partner's (woman's) luteal learning data for accurate cycle display
    func getPartnerLutealLearning() async throws -> Int {
        guard let couple = try await getCouple(), couple.isLinked, let womanId = couple.womanId else {
            return 14  // Default if not linked or no woman
        }
        
        let (averageLutealLength, lutealSamples) = try await getLutealLearning(for: womanId)
        
        // Only use personalized value if we have learning data
        return lutealSamples > 0 ? averageLutealLength : 14
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
        let dateString = dateOnlyFormatter.string(from: date)
        
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
        } else if let couple = try? await getCouple(), couple.isLinked, let womanId = couple.womanId {
            // Partner - get the woman's cycle
            let cycle: CycleRecord? = try await client
                .from("cycles")
                .select()
                .eq("user_id", value: womanId.uuidString)
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
        
        let dateString = dateOnlyFormatter.string(from: date)
        
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
    var profilePhotoUrl: String?
    // Cycle learning: personalized luteal phase
    var averageLutealLength: Int
    var lutealSamples: Int
    // Temperature tracking preferences (optional feature, OFF by default)
    var temperatureTrackingEnabled: Bool
    var temperatureInfoAcknowledged: Bool
    var temperatureUnit: String  // "celsius" or "fahrenheit"
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, role
        case coupleId = "couple_id"
        case notificationTone = "notification_tone"
        case notificationsEnabled = "notifications_enabled"
        case pushToken = "push_token"
        case profilePhotoUrl = "profile_photo_url"
        case averageLutealLength = "average_luteal_length"
        case lutealSamples = "luteal_samples"
        case temperatureTrackingEnabled = "temperature_tracking_enabled"
        case temperatureInfoAcknowledged = "temperature_info_acknowledged"
        case temperatureUnit = "temperature_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        coupleId = try container.decodeIfPresent(UUID.self, forKey: .coupleId)
        notificationTone = try container.decode(String.self, forKey: .notificationTone)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        pushToken = try container.decodeIfPresent(String.self, forKey: .pushToken)
        profilePhotoUrl = try container.decodeIfPresent(String.self, forKey: .profilePhotoUrl)
        // Provide defaults for new fields (backwards compatibility)
        averageLutealLength = try container.decodeIfPresent(Int.self, forKey: .averageLutealLength) ?? 14
        lutealSamples = try container.decodeIfPresent(Int.self, forKey: .lutealSamples) ?? 0
        // Temperature tracking: OFF by default
        temperatureTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .temperatureTrackingEnabled) ?? false
        temperatureInfoAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .temperatureInfoAcknowledged) ?? false
        temperatureUnit = try container.decodeIfPresent(String.self, forKey: .temperatureUnit) ?? "celsius"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
    var profilePhotoUrl: String?
    var averageLutealLength: Int?
    var lutealSamples: Int?
    // Temperature tracking preferences
    var temperatureTrackingEnabled: Bool?
    var temperatureInfoAcknowledged: Bool?
    var temperatureUnit: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case notificationTone = "notification_tone"
        case notificationsEnabled = "notifications_enabled"
        case pushToken = "push_token"
        case profilePhotoUrl = "profile_photo_url"
        case averageLutealLength = "average_luteal_length"
        case lutealSamples = "luteal_samples"
        case temperatureTrackingEnabled = "temperature_tracking_enabled"
        case temperatureInfoAcknowledged = "temperature_info_acknowledged"
        case temperatureUnit = "temperature_unit"
    }
}

struct Couple: Codable {
    let id: UUID
    var womanId: UUID?  // Optional: null when partner creates the couple
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
    // Temperature tracking (optional)
    // Note: Temperature is currently stored and displayed only.
    // It is NOT used to drive ovulation prediction or fertile window logic.
    // Future versions may use temperature as a secondary confirmation signal.
    var temperature: Double?
    var temperatureLoggedAt: Date?
    
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
        case temperature
        case temperatureLoggedAt = "temperature_logged_at"
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
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        
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
        
        // Parse temperatureLoggedAt (optional)
        if let loggedAtString = try container.decodeIfPresent(String.self, forKey: .temperatureLoggedAt) {
            if let parsedDate = iso8601Formatter.date(from: loggedAtString) {
                temperatureLoggedAt = parsedDate
            } else {
                temperatureLoggedAt = nil
            }
        } else {
            temperatureLoggedAt = nil
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
    case syncFailed(String)
    
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
        case .syncFailed(let message):
            return message
        }
    }
}
