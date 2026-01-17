//
//  AppViewModel.swift
//  Moment
//
//  Main app state management
//

import Foundation
import SwiftUI
import Supabase

@Observable
final class AppViewModel {
    // Services
    private let dataService = DataService.shared
    private let notificationService = NotificationService.shared
    private let supabaseService = SupabaseService.shared
    private let pushService = PushNotificationService.shared
    private let networkService = NetworkService.shared
    
    // Network state
    var isOffline: Bool { !networkService.isConnected }
    var pendingChanges: Int { networkService.pendingCount }
    
    // Navigation state
    var currentScreen: AppScreen = .loading
    var showingSettings = false
    var showingLogPeriod = false
    var showingLogLH = false
    var showingSignOutAlert = false
    
    // Auth state
    var isAuthenticated: Bool { supabaseService.isAuthenticated }
    var isCheckingAuth = true
    
    // Onboarding state
    var onboardingStep: OnboardingStep = .welcome
    var userName = ""
    var selectedRole: UserRole = .woman
    var selectedTone: NotificationTone = .discreet
    var inviteCode = ""
    var partnerInviteCode = ""
    var isJoining = false
    var joinError: String?
    var isCreatingProfile = false
    var profileError: String?
    
    // Cycle state
    var periodStartDate = Date()
    var selectedLHResult: LHTestResult?
    
    // Supabase data
    var supabaseProfile: Profile?
    var supabaseCouple: Couple?
    var supabaseCycle: CycleRecord?
    
    // Computed properties (fallback to local if no Supabase)
    var currentUser: User? { dataService.currentUser }
    var localCouple: LocalCouple? { dataService.couple }
    var currentCycle: Cycle? { dataService.currentCycle }
    var todaysCycleDay: CycleDay? { dataService.getTodaysCycleDay() }
    var isInFertileWindow: Bool { dataService.isInFertileWindow() }
    
    var actionCard: ActionCard? {
        guard let user = currentUser,
              let cycleDay = todaysCycleDay else { return nil }
        
        let isLHPositive = cycleDay.lhTestResult == .positive
        
        if user.role == .woman {
            return ActionCard.forWoman(fertilityLevel: cycleDay.fertilityLevel, isLHPositive: isLHPositive)
        } else {
            return ActionCard.forPartner(fertilityLevel: cycleDay.fertilityLevel, isLHPositive: isLHPositive, tone: user.notificationTone)
        }
    }
    
    init() {
        setupNotificationObservers()
        Task {
            await checkAuthState()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .navigateToToday,
            object: nil,
            queue: .main
        ) { _ in
            // Already on home, could switch to today tab if needed
        }
        
        NotificationCenter.default.addObserver(
            forName: .openLHLogging,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showingLogLH = true
        }
        
        // Refresh data when app comes to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCycleData()
            }
        }
    }
    
    @MainActor
    func refreshCycleData() async {
        guard currentScreen == .home else { return }
        guard let role = currentUser?.role else { return }
        
        if role == .woman {
            // Refresh from Supabase
            if let cycle = try? await supabaseService.getActiveCycle() {
                supabaseCycle = cycle
                syncCycleToLocal(cycle)
            }
        }
        // Partner data is refreshed in their respective views
    }
    
    // MARK: - Auth
    
    @MainActor
    func checkAuthState() async {
        isCheckingAuth = true
        
        // Check if user is authenticated with Supabase
        if supabaseService.client.auth.currentSession != nil {
            // User is logged in, check if they have a profile
            do {
                let profile = try await supabaseService.getProfile()
                supabaseProfile = profile
                
                // Sync to local storage for offline support
                let localUser = User(
                    id: profile.id,
                    name: profile.name,
                    role: UserRole(rawValue: profile.role) ?? .woman,
                    coupleId: profile.coupleId
                )
                dataService.currentUser = localUser
                
                if profile.role == "woman" {
                    // Check if has active cycle in Supabase
                    if let cycle = try? await supabaseService.getActiveCycle() {
                        supabaseCycle = cycle
                        
                        // Ensure cycle has couple_id for partner access
                        if cycle.coupleId == nil {
                            print("⚠️ Cycle missing couple_id, updating...")
                            try? await supabaseService.ensureCycleHasCoupleId()
                            // Refresh cycle data
                            if let updatedCycle = try? await supabaseService.getActiveCycle() {
                                supabaseCycle = updatedCycle
                            }
                        }
                        
                        // Sync to local storage for offline support
                        syncCycleToLocal(cycle)
                        
                        currentScreen = .home
                    } else if let localCycle = dataService.currentCycle {
                        // Have local cycle but not in Supabase - sync it up
                        print("📱 Found local cycle, syncing to Supabase...")
                        do {
                            let remoteCycle = try await supabaseService.createCycle(
                                startDate: localCycle.startDate,
                                cycleLength: localCycle.cycleLength
                            )
                            supabaseCycle = remoteCycle
                            print("✅ Local cycle synced to Supabase")
                        } catch {
                            print("❌ Failed to sync local cycle: \(error)")
                        }
                        currentScreen = .home
                    } else {
                        currentScreen = .setupCycle
                    }
                } else {
                    // Partner: check if connected to a couple
                    if profile.coupleId != nil {
                        currentScreen = .home
                    } else {
                        // Partner not connected, show invite code screen
                        selectedRole = .partner
                        userName = profile.name
                        currentScreen = .onboarding
                        onboardingStep = .enterInviteCode
                    }
                }
                
                // Request push notifications after successful auth
                Task {
                    await pushService.requestPermissionAndRegister()
                }
            } catch {
                // Profile doesn't exist, needs onboarding
                currentScreen = .onboarding
                onboardingStep = .selectRole
            }
        } else {
            // Not authenticated
            currentScreen = .auth
        }
        
        isCheckingAuth = false
    }
    
    func signOut() async {
        do {
            try await supabaseService.signOut()
            dataService.resetAllData()
            await MainActor.run {
                currentScreen = .auth
            }
        } catch {
            print("Sign out error: \(error)")
        }
    }
    
    // MARK: - Navigation
    
    func determineInitialScreen() {
        // This is now handled by checkAuthState() for Supabase users
        // Keeping for backwards compatibility with local-only mode
        if !dataService.hasSeenWelcome {
            currentScreen = .onboarding
        } else if dataService.currentUser == nil {
            currentScreen = .auth
        } else if dataService.currentUser?.role == .woman && dataService.currentCycle == nil {
            currentScreen = .setupCycle
        } else {
            currentScreen = .home
        }
    }
    
    // MARK: - Onboarding
    
    func completeWelcome() {
        dataService.hasSeenWelcome = true
        onboardingStep = .selectRole
    }
    
    func selectRole(_ role: UserRole) {
        selectedRole = role
        if role == .woman {
            onboardingStep = .enterName
        } else {
            onboardingStep = .enterInviteCode
        }
    }
    
    func goBackInOnboarding() {
        switch onboardingStep {
        case .welcome:
            break // Can't go back from welcome
        case .selectRole:
            onboardingStep = .welcome
        case .enterName:
            onboardingStep = .selectRole
        case .enterInviteCode:
            onboardingStep = .selectRole
        case .selectTone:
            onboardingStep = .enterName
        case .invitePartner:
            onboardingStep = .selectTone
        }
    }
    
    func submitName() {
        guard !userName.isEmpty else { return }
        
        if selectedRole == .woman {
            isCreatingProfile = true
            profileError = nil
            
            Task {
                do {
                    guard let userId = supabaseService.client.auth.currentUser?.id else {
                        await MainActor.run {
                            profileError = "Not signed in"
                            isCreatingProfile = false
                        }
                        return
                    }
                    
                    print("📝 Creating woman profile for user: \(userId)")
                    
                    // Check if profile already exists
                    let existingProfile: Profile? = try? await supabaseService.client
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    
                    var createdProfile: Profile
                    
                    if let existing = existingProfile {
                        print("✅ Profile already exists, using existing")
                        createdProfile = existing
                    } else {
                        // Step 1: Create profile
                        let profile = ProfileInsert(
                            id: userId,
                            name: userName,
                            role: UserRole.woman.rawValue,
                            notificationTone: "discreet",
                            notificationsEnabled: true
                        )
                        
                        createdProfile = try await supabaseService.client
                            .from("profiles")
                            .insert(profile)
                            .select()
                            .single()
                            .execute()
                            .value
                        
                        print("✅ Profile created")
                    }
                    
                    // Step 2: Check if couple already exists, if not create one
                    var finalInviteCode: String
                    
                    let existingCouple: Couple? = try? await supabaseService.client
                        .from("couples")
                        .select()
                        .eq("woman_id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    
                    if let couple = existingCouple {
                        print("✅ Couple already exists with code: \(couple.inviteCode)")
                        finalInviteCode = couple.inviteCode
                    } else {
                        finalInviteCode = generateInviteCode()
                        
                        struct CoupleInsert: Encodable {
                            let woman_id: String
                            let invite_code: String
                        }
                        
                        let coupleData = CoupleInsert(
                            woman_id: userId.uuidString,
                            invite_code: finalInviteCode
                        )
                        
                        let createdCouple: Couple = try await supabaseService.client
                            .from("couples")
                            .insert(coupleData)
                            .select()
                            .single()
                            .execute()
                            .value
                        
                        print("✅ Couple created with code: \(finalInviteCode)")
                        
                        // Update profile with couple_id
                        struct ProfileCoupleUpdate: Encodable {
                            let couple_id: String
                        }
                        
                        try await supabaseService.client
                            .from("profiles")
                            .update(ProfileCoupleUpdate(couple_id: createdCouple.id.uuidString))
                            .eq("id", value: userId.uuidString)
                            .execute()
                        
                        print("✅ Profile linked to couple")
                    }
                    
                    // Also create local user for offline support
                    _ = dataService.createUser(name: userName, role: .woman)
                    
                    await MainActor.run {
                        supabaseProfile = createdProfile
                        partnerInviteCode = finalInviteCode
                        isCreatingProfile = false
                        onboardingStep = .selectTone
                    }
                    
                } catch {
                    print("❌ Error: \(error)")
                    await MainActor.run {
                        profileError = "Error: \(error.localizedDescription)"
                        isCreatingProfile = false
                    }
                }
            }
        } else {
            // Partner flow handled in joinWithInviteCode
        }
    }
    
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    func selectNotificationTone(_ tone: NotificationTone) {
        selectedTone = tone
        if var user = dataService.currentUser {
            user.notificationTone = tone
            dataService.currentUser = user
        }
        onboardingStep = .invitePartner
    }
    
    func joinWithInviteCode() {
        guard !inviteCode.isEmpty, !userName.isEmpty else { return }
        
        isJoining = true
        joinError = nil
        
        Task {
            do {
                guard let userId = supabaseService.client.auth.currentUser?.id else {
                    await MainActor.run {
                        joinError = "Please sign in first"
                        isJoining = false
                    }
                    return
                }
                
                print("🔄 Starting join process for user: \(userId)")
                
                // Check if profile already exists in database
                let existingProfile: Profile? = try? await supabaseService.client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                if existingProfile != nil {
                    print("✅ Profile already exists, skipping creation")
                } else {
                    print("📝 Creating new partner profile...")
                    let profile = ProfileInsert(
                        id: userId,
                        name: userName,
                        role: UserRole.partner.rawValue,
                        notificationTone: "discreet",
                        notificationsEnabled: true
                    )
                    
                    let createdProfile: Profile = try await supabaseService.client
                        .from("profiles")
                        .insert(profile)
                        .select()
                        .single()
                        .execute()
                        .value
                    
                    print("✅ Profile created: \(createdProfile.id)")
                    
                    await MainActor.run {
                        supabaseProfile = createdProfile
                    }
                }
                
                // Join the couple using the invite code
                print("🔗 Joining couple with code: \(inviteCode)")
                let result = try await supabaseService.joinCouple(inviteCode: inviteCode)
                
                print("📦 Join result: success=\(result.success), error=\(result.error ?? "none")")
                
                await MainActor.run {
                    isJoining = false
                    if result.success {
                        print("✅ Successfully joined couple!")
                        completeOnboarding()
                    } else {
                        joinError = result.error ?? "Invalid invite code"
                    }
                }
            } catch {
                print("❌ Error joining couple: \(error)")
                await MainActor.run {
                    joinError = "Error: \(error.localizedDescription)"
                    isJoining = false
                }
            }
        }
    }
    
    func skipPartnerInvite() {
        completeOnboarding()
    }
    
    func completeOnboarding() {
        dataService.isOnboardingComplete = true
        
        // Request notification permission
        Task {
            await notificationService.requestPermission()
        }
        
        if selectedRole == .woman {
            currentScreen = .setupCycle
        } else {
            currentScreen = .home
        }
    }
    
    // MARK: - Cycle Sync
    
    private func syncCycleToLocal(_ remoteCycle: CycleRecord) {
        // Convert Supabase cycle to local cycle format
        var localCycle = Cycle(
            id: remoteCycle.id,
            userId: remoteCycle.userId,
            startDate: remoteCycle.startDate,
            cycleLength: remoteCycle.cycleLength
        )
        
        // Generate days if not present from remote
        if let remoteDays = remoteCycle.cycleDays, !remoteDays.isEmpty {
            localCycle.days = remoteDays.map { remoteDay in
                var day = CycleDay(
                    id: remoteDay.id,
                    date: remoteDay.date,
                    fertilityLevel: FertilityLevel(rawValue: remoteDay.fertilityLevel) ?? .low,
                    isMenstruation: remoteDay.isMenstruation
                )
                day.lhTestResult = remoteDay.lhTestResult.flatMap { LHTestResult(rawValue: $0) }
                day.lhTestLoggedAt = remoteDay.lhTestLoggedAt
                return day
            }
        } else {
            localCycle.generateDays()
        }
        
        localCycle.isActive = remoteCycle.isActive
        localCycle.endDate = remoteCycle.endDate
        
        // Save to local storage
        dataService.currentCycle = localCycle
        
        print("✅ Synced cycle to local storage: \(localCycle.days.count) days")
    }
    
    // MARK: - Cycle Management
    
    func startNewCycle(startDate: Date) {
        // Update UI immediately for snappy response
        currentScreen = .home
        showingLogPeriod = false
        
        // Save locally (synchronous, quick operation)
        let localCycle = dataService.startNewCycle(startDate: startDate)
        
        // Schedule notifications
        notificationService.scheduleDailyNotifications()
        notificationService.sendCycleStartNotification()
        
        // Sync to Supabase in background
        Task {
            do {
                let remoteCycle = try await supabaseService.createCycle(
                    startDate: startDate,
                    cycleLength: localCycle.cycleLength
                )
                supabaseCycle = remoteCycle
                print("✅ Cycle synced to Supabase")
            } catch {
                print("❌ Failed to sync cycle to Supabase: \(error)")
                // Queue for later if offline
                let isConnected = networkService.isConnected
                if !isConnected {
                    networkService.queueOperation(
                        PendingOperation(type: .createCycle, data: [
                            "startDate": ISO8601DateFormatter().string(from: startDate),
                            "cycleLength": String(localCycle.cycleLength)
                        ])
                    )
                }
            }
        }
    }
    
    func logMenstruation(date: Date = Date()) {
        // Starting new cycle
        startNewCycle(startDate: date)
    }
    
    // MARK: - LH Test
    
    func logLHTest(result: LHTestResult) {
        dataService.logLHTest(result: result)
        
        if result == .positive {
            notificationService.sendLHPositiveAlert()
        }
        
        notificationService.scheduleDailyNotifications()
        showingLogLH = false
        selectedLHResult = nil
    }
    
    // MARK: - Intimacy Logging
    
    func logIntimacy(for date: Date = Date(), remove: Bool = false) {
        // Update locally first
        if remove {
            dataService.removeIntimacy(for: date)
        } else {
            dataService.logIntimacy(for: date)
        }
        
        // Sync to Supabase
        Task {
            do {
                try await supabaseService.logIntimacy(date: date, hadIntimacy: !remove)
                print("✅ Intimacy synced to Supabase")
            } catch {
                print("❌ Failed to sync intimacy: \(error)")
                // Queue for later if offline
                if !networkService.isConnected {
                    networkService.queueOperation(
                        PendingOperation(type: .logIntimacy, data: [
                            "date": ISO8601DateFormatter().string(from: date),
                            "hadIntimacy": remove ? "false" : "true"
                        ])
                    )
                }
            }
        }
    }
    
    func removeIntimacy(for date: Date) {
        logIntimacy(for: date, remove: true)
    }
    
    func toggleIntimacy(for date: Date) {
        guard let cycle = currentCycle else { return }
        let calendar = Calendar.current
        
        if let day = cycle.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            logIntimacy(for: date, remove: day.hadIntimacy)
        } else {
            // Day doesn't exist in array, just log it
            logIntimacy(for: date)
        }
    }
    
    // MARK: - Notify Partner
    
    func notifyPartnerNow() async throws {
        guard let couple = localCouple, couple.isLinked, let partnerId = couple.partnerId else {
            return
        }
        
        let fertilityLevel = todaysCycleDay?.fertilityLevel ?? .low
        let isLHPositive = todaysCycleDay?.lhTestResult == .positive
        let tone = dataService.currentUser?.notificationTone ?? .discreet
        
        let title: String
        let body: String
        
        if isLHPositive {
            title = tone == .explicit ? "Peak Fertility Now" : "Important Moment"
            body = tone == .explicit ? "LH surge detected — this is the best time" : "Your partner wants to connect with you"
        } else {
            switch fertilityLevel {
            case .peak:
                title = tone == .explicit ? "Peak Fertility" : "Special Moment"
                body = tone == .explicit ? "Today is a great day to try" : "Your partner is thinking of you"
            case .high:
                title = tone == .explicit ? "High Fertility" : "Good Timing"
                body = tone == .explicit ? "Good timing for the next few days" : "Your partner wants to connect"
            case .low:
                title = tone == .explicit ? "Fertility Update" : "Moment"
                body = tone == .explicit ? "Lower fertility right now" : "A gentle reminder from your partner"
            }
        }
        
        try await supabaseService.sendPushNotification(
            to: partnerId,
            title: title,
            body: body,
            data: ["type": "manual_update", "fertility": fertilityLevel.rawValue]
        )
    }
    
    // MARK: - Settings
    
    func updateNotificationTone(_ tone: NotificationTone) {
        guard var user = dataService.currentUser else { return }
        user.notificationTone = tone
        dataService.currentUser = user
        notificationService.scheduleDailyNotifications()
        
        // Sync to Supabase (with offline support)
        if networkService.isConnected {
            Task {
                do {
                    _ = try await networkService.withRetry { [self] in
                        try await self.supabaseService.updateProfile(
                            ProfileUpdate(notificationTone: tone.rawValue)
                        )
                    }
                } catch {
                    print("Failed to sync notification tone: \(error)")
                    // Queue for later
                    networkService.queueOperation(
                        PendingOperation(type: .updateNotificationSettings, data: ["notificationTone": tone.rawValue])
                    )
                }
            }
        } else {
            // Queue for when back online
            networkService.queueOperation(
                PendingOperation(type: .updateNotificationSettings, data: ["notificationTone": tone.rawValue])
            )
        }
    }
    
    func toggleNotifications(_ enabled: Bool) {
        guard var user = dataService.currentUser else { return }
        user.notificationsEnabled = enabled
        dataService.currentUser = user
        
        if enabled {
            notificationService.scheduleDailyNotifications()
        }
        
        // Sync to Supabase (with offline support)
        if networkService.isConnected {
            Task {
                do {
                    _ = try await networkService.withRetry { [self] in
                        try await self.supabaseService.updateProfile(
                            ProfileUpdate(notificationsEnabled: enabled)
                        )
                    }
                } catch {
                    print("Failed to sync notifications enabled: \(error)")
                    // Queue for later
                    networkService.queueOperation(
                        PendingOperation(type: .updateNotificationSettings, data: ["notificationsEnabled": String(enabled)])
                    )
                }
            }
        } else {
            // Queue for when back online
            networkService.queueOperation(
                PendingOperation(type: .updateNotificationSettings, data: ["notificationsEnabled": String(enabled)])
            )
        }
    }
    
    func resetApp() async {
        // Delete Supabase data first
        do {
            try await supabaseService.deleteUserData()
            print("✅ Supabase data deleted")
        } catch {
            print("⚠️ Error deleting Supabase data: \(error)")
        }
        
        // Reset local data
        dataService.resetAllData()
        
        await MainActor.run {
            currentScreen = .onboarding
            onboardingStep = .welcome
            userName = ""
            inviteCode = ""
            partnerInviteCode = ""
            supabaseProfile = nil
            // localCouple is computed from dataService.couple, which is cleared by resetAllData()
        }
    }
}

// MARK: - App Navigation

enum AppScreen {
    case loading
    case auth
    case onboarding
    case setupCycle
    case home
}

enum OnboardingStep {
    case welcome
    case selectRole
    case enterName
    case enterInviteCode  // Partner only
    case selectTone       // Woman only
    case invitePartner    // Woman only
}
