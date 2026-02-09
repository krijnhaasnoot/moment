//
//  HomeView.swift
//  Moment
//
//  Main dashboard with action card - the heart of the app
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab: HomeTab = .today
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.momentBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Offline banner
                    if viewModel.isOffline {
                        OfflineBanner(pendingChanges: viewModel.pendingChanges)
                    }
                    
                    // Header
                    HomeHeader(viewModel: viewModel)
                    
                    // Tab selector
                    TabSelector(selectedTab: $selectedTab)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        TodayView(viewModel: viewModel)
                            .tag(HomeTab.today)
                        
                        CalendarView(viewModel: viewModel)
                            .tag(HomeTab.calendar)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .sheet(isPresented: $viewModel.showingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingLogPeriod) {
                LogPeriodSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingLogLH) {
                LogLHSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        if isPresented {
            VStack {
                Spacer()
                
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.momentGreen)
                    
                    Text(message)
                        .font(.momentCaptionMedium)
                        .foregroundColor(.momentCharcoal)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.momentCardBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/// Helper to format date for toast messages
private func formatDateForToast(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    return formatter.string(from: date)
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    let pendingChanges: Int
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14))
            
            Text("Offline")
                .font(.momentCaptionMedium)
            
            if pendingChanges > 0 {
                Text("• \(pendingChanges) pending")
                    .font(.momentCaption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.momentWarmGray)
    }
}

// MARK: - Home Tab

enum HomeTab: String, CaseIterable {
    case today = "Today"
    case calendar = "Calendar"
}

struct TabSelector: View {
    @Binding var selectedTab: HomeTab
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.momentSpring) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.momentCaptionMedium)
                        .foregroundColor(selectedTab == tab ? .momentCharcoal : .momentSecondaryText)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.momentCardBackground : Color.clear)
                                .shadow(color: selectedTab == tab ? Color.black.opacity(0.05) : .clear, radius: 4, y: 2)
                        )
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Home Header

struct HomeHeader: View {
    @Bindable var viewModel: AppViewModel
    @State private var partnerProfile: Profile?
    
    var isConnected: Bool {
        viewModel.localCouple?.isLinked ?? false
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(greeting)
                    .font(.momentCaption)
                    .foregroundColor(.momentSecondaryText)
                
                Text(viewModel.currentUser?.name ?? "")
                    .font(.momentHeadline)
                    .foregroundColor(.momentCharcoal)
            }
            
            Spacer()
            
            HStack(spacing: Spacing.sm) {
                // Partner photo (when connected)
                if isConnected {
                    partnerPhotoView
                        .transition(.scale.combined(with: .opacity))
                }
                
                Button {
                    viewModel.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundColor(.momentWarmGray)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .task {
            if isConnected {
                await fetchPartnerProfile()
            }
        }
    }
    
    @ViewBuilder
    var partnerPhotoView: some View {
        if let photoUrl = partnerProfile?.profilePhotoUrl,
           let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.momentGreen, lineWidth: 1.5)
                        )
                case .failure(_), .empty:
                    partnerInitialsView
                @unknown default:
                    partnerInitialsView
                }
            }
        } else {
            partnerInitialsView
        }
    }
    
    @ViewBuilder
    var partnerInitialsView: some View {
        Circle()
            .fill(Color.momentGreen.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Text(partnerInitials)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.momentGreen)
            )
            .overlay(
                Circle()
                    .stroke(Color.momentGreen, lineWidth: 1.5)
            )
    }
    
    var partnerInitials: String {
        guard let name = partnerProfile?.name else { return "?" }
        let components = name.split(separator: " ")
        if let first = components.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    func fetchPartnerProfile() async {
        do {
            partnerProfile = try await SupabaseService.shared.getPartnerProfile()
        } catch {
            print("❌ Error fetching partner profile: \(error)")
        }
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
}

// MARK: - Today View

/*
 SCREEN: Today / Action Card
 PURPOSE: Single daily card with fertility status and recommendation
 COPY EXAMPLES:
 
 Woman - Peak:
   Status: "Peak fertility"
   Message: "This is your most fertile time"
 
 Woman - High:
   Status: "High fertility"
   Message: "Good timing for intimacy"
 
 Partner - Peak (Explicit):
   Status: "Peak fertility"
   Message: "Great timing today or tomorrow"
 
 Partner - High (Discreet):
   Status: "Good timing"
   Message: "Your partner may want to connect"
*/

struct TodayView: View {
    @Bindable var viewModel: AppViewModel
    @State private var refreshTrigger = UUID()
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var isPartner: Bool {
        viewModel.currentUser?.role == .partner
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Action Card
                    ActionCardView(viewModel: viewModel, refreshTrigger: refreshTrigger)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                    
                    // Fertility Forecast (both roles)
                    FertilityForecastView(viewModel: viewModel, refreshTrigger: refreshTrigger)
                        .padding(.horizontal, Spacing.lg)
                    
                    // Pregnancy test timing (woman only, after ovulation)
                    if viewModel.currentUser?.role == .woman {
                        PregnancyTestInfoView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Quick actions
                    if viewModel.currentUser?.role == .woman {
                        QuickActionsView(viewModel: viewModel, onIntimacyLogged: { date, logged in
                            showIntimacyToast(for: date, logged: logged)
                        })
                            .padding(.horizontal, Spacing.lg)
                        
                        // Temperature logging (optional, only shown if enabled)
                        if viewModel.isTemperatureTrackingEnabled {
                            TemperatureLoggingView(viewModel: viewModel)
                                .padding(.horizontal, Spacing.lg)
                        }
                    } else {
                        // Partner quick actions (just intimacy logging)
                        PartnerQuickActionsView(viewModel: viewModel, onIntimacyLogged: { date, logged in
                            showIntimacyToast(for: date, logged: logged)
                        })
                            .padding(.horizontal, Spacing.lg)
                    }
                    
                    Spacer(minLength: Spacing.xxl)
                }
            }
            .refreshable {
                if isPartner {
                    // Trigger refresh of child views
                    refreshTrigger = UUID()
                    // Small delay to allow views to react
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    // Woman: refresh cycle data from Supabase
                    await viewModel.refreshCycleData()
                }
            }
            
            // Toast overlay
            ToastView(message: toastMessage, isPresented: $showToast)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToast)
        }
    }
    
    private func showIntimacyToast(for date: Date, logged: Bool) {
        let dateString = formatDateForToast(date)
        toastMessage = logged ? "Intimacy logged for \(dateString)" : "Intimacy removed for \(dateString)"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showToast = true
        }
    }
}

// MARK: - Action Card

struct ActionCardView: View {
    @Bindable var viewModel: AppViewModel
    var refreshTrigger: UUID = UUID()
    @State private var partnerFertilityLevel: FertilityLevel?
    @State private var partnerLHPositive: Bool = false
    @State private var isLoadingPartnerData = false
    
    var isPartner: Bool {
        viewModel.currentUser?.role == .partner
    }
    
    var fertilityLevel: FertilityLevel {
        if isPartner {
            return partnerFertilityLevel ?? .low
        }
        return viewModel.todaysCycleDay?.fertilityLevel ?? .low
    }
    
    var isLHPositive: Bool {
        if isPartner {
            return partnerLHPositive
        }
        return viewModel.todaysCycleDay?.lhTestResult == .positive
    }
    
    var fertilityColor: Color {
        isPartner
            ? Color.partnerFertilityColor(for: fertilityLevel)
            : Color.fertilityColor(for: fertilityLevel)
    }
    
    var actionCard: ActionCard? {
        if isPartner {
            guard partnerFertilityLevel != nil else { return nil }
            return ActionCard.forPartner(
                fertilityLevel: fertilityLevel,
                isLHPositive: partnerLHPositive,
                tone: viewModel.currentUser?.notificationTone ?? .discreet
            )
        }
        return viewModel.actionCard
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status indicator
            HStack {
                if isPartner && isLoadingPartnerData {
                    ProgressView()
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(fertilityColor)
                        .frame(width: 12, height: 12)
                }
                
                Text(dayStatus)
                    .font(.momentCaptionMedium)
                    .foregroundColor(.momentSecondaryText)
                
                Spacer()
                
                Text(formattedDate)
                    .font(.momentCaption)
                    .foregroundColor(.momentSecondaryText)
            }
            .padding(.bottom, Spacing.lg)
            
            // Main content
            VStack(spacing: Spacing.sm) {
                if let card = actionCard {
                    Text(card.headline)
                        .font(.momentDisplaySmall)
                        .foregroundColor(.momentCharcoal)
                        .multilineTextAlignment(.center)
                    
                    Text(card.recommendation)
                        .font(.momentBody)
                        .foregroundColor(.momentSecondaryText)
                        .multilineTextAlignment(.center)
                } else if isPartner && isLoadingPartnerData {
                    ProgressView()
                        .padding()
                } else if isPartner {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.momentWarmGray)
                        
                        Text("Waiting for cycle data")
                            .font(.momentSubheadline)
                            .foregroundColor(.momentCharcoal)
                        
                        Text("Your partner's fertility status will appear here")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("No cycle data yet")
                        .font(.momentSubheadline)
                        .foregroundColor(.momentSecondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            
            // Cycle day indicator (woman only)
            if !isPartner, let cycle = viewModel.currentCycle {
                let dayNumber = cycleDayNumber(cycle: cycle)
                HStack {
                    Text("Cycle day \(dayNumber)")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    Spacer()
                    
                    // Mini fertility indicator
                    HStack(spacing: Spacing.xxs) {
                        ForEach(0..<7, id: \.self) { i in
                            Circle()
                                .fill(dotColor(for: i, dayNumber: dayNumber, cycle: cycle))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.momentCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(fertilityColor.opacity(0.3), lineWidth: 2)
        )
        .momentShadow()
        .task {
            if isPartner {
                await loadPartnerData()
            }
        }
        .task(id: refreshTrigger) {
            if isPartner {
                await loadPartnerData()
            }
        }
    }
    
    var dayStatus: String {
        if isLHPositive {
            return "LH Surge Detected"
        }
        if isPartner && partnerFertilityLevel == nil && !isLoadingPartnerData {
            return "Waiting..."
        }
        return "\(fertilityLevel.displayName) Fertility"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    func cycleDayNumber(cycle: Cycle) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return days + 1
    }
    
    func dotColor(for index: Int, dayNumber: Int, cycle: Cycle) -> Color {
        let dayIndex = dayNumber - 4 + index // Center current day
        guard dayIndex > 0 && dayIndex <= cycle.days.count else {
            return Color.momentMist.opacity(0.3)
        }
        
        let cycleDay = cycle.days[dayIndex - 1]
        let isToday = index == 3
        
        let color = Color.fertilityColor(for: cycleDay.fertilityLevel)
        return isToday ? color : color.opacity(0.4)
    }
    
    func loadPartnerData() async {
        isLoadingPartnerData = true
        do {
            print("🔄 Loading partner cycle data...")
            print("🔍 Current user role: \(viewModel.currentUser?.role.rawValue ?? "nil")")
            
            if let cycle = try await SupabaseService.shared.getPartnerCycle() {
                print("✅ Got partner cycle: \(cycle.id)")
                print("   couple_id: \(cycle.coupleId?.uuidString ?? "nil")")
                print("   days count: \(cycle.cycleDays?.count ?? 0)")
                
                if let days = cycle.cycleDays {
                    print("   First 3 days: \(days.prefix(3).map { "\($0.date) - \($0.fertilityLevel)" })")
                }
                
                // Find today's cycle day
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                print("   Looking for date: \(today)")
                
                if let todayData = cycle.cycleDays?.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    print("✅ Found today's data: \(todayData.fertilityLevel)")
                    await MainActor.run {
                        partnerFertilityLevel = FertilityLevel(rawValue: todayData.fertilityLevel)
                        partnerLHPositive = todayData.lhTestResult == "positive"
                    }
                } else {
                    print("⚠️ No cycle day found for today in \(cycle.cycleDays?.count ?? 0) days")
                    // Try to find closest day for debugging
                    if let firstDay = cycle.cycleDays?.first, let lastDay = cycle.cycleDays?.last {
                        print("   Cycle range: \(firstDay.date) to \(lastDay.date)")
                    }
                }
            } else {
                print("⚠️ No partner cycle found - couple may not be linked or no active cycle")
            }
        } catch {
            print("❌ Failed to load partner data: \(error)")
        }
        await MainActor.run {
            isLoadingPartnerData = false
        }
    }
}

// MARK: - Quick Actions

// MARK: - Fertility Forecast

struct FertilityForecastView: View {
    @Bindable var viewModel: AppViewModel
    var refreshTrigger: UUID = UUID()
    @State private var partnerForecast: [(date: Date, level: FertilityLevel)] = []
    @State private var isLoadingPartnerForecast = false
    
    var isPartner: Bool {
        viewModel.currentUser?.role == .partner
    }
    
    var forecastDays: [(date: Date, level: FertilityLevel)] {
        if isPartner {
            return partnerForecast
        }
        
        guard let cycle = viewModel.currentCycle else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var days: [(Date, FertilityLevel)] = []
        
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            
            // Find the day in the cycle
            if let dayIndex = cycle.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                days.append((date, cycle.days[dayIndex].fertilityLevel))
            } else {
                // Calculate from start date if not in days array
                let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: cycle.startDate), to: date).day ?? 0
                if daysSinceStart >= 0 && daysSinceStart < cycle.days.count {
                    days.append((date, cycle.days[daysSinceStart].fertilityLevel))
                } else {
                    days.append((date, .low))
                }
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("This Week")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            MomentCard {
                if isPartner && isLoadingPartnerForecast {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                } else if forecastDays.isEmpty {
                    Text(isPartner ? "Waiting for your partner to start tracking" : "Start tracking to see your forecast")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                } else {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(forecastDays.enumerated()), id: \.offset) { index, day in
                            VStack(spacing: Spacing.xs) {
                                Text(dayLabel(for: day.date, index: index))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(index == 0 ? .momentCharcoal : .momentSecondaryText)
                                
                                Circle()
                                    .fill(isPartner ? Color.partnerFertilityColor(for: day.level) : Color.fertilityColor(for: day.level))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(index == 0 ? Color.momentCharcoal : Color.clear, lineWidth: 2)
                                    )
                                
                                Text(day.level.shortName)
                                    .font(.system(size: 9))
                                    .foregroundColor(.momentSecondaryText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .task {
            if isPartner {
                await loadPartnerForecast()
            }
        }
        .task(id: refreshTrigger) {
            if isPartner {
                await loadPartnerForecast()
            }
        }
    }
    
    func dayLabel(for date: Date, index: Int) -> String {
        if index == 0 { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    func loadPartnerForecast() async {
        isLoadingPartnerForecast = true
        defer { 
            Task { @MainActor in
                isLoadingPartnerForecast = false 
            }
        }
        
        do {
            print("🔄 Loading partner forecast...")
            if let cycle = try await SupabaseService.shared.getPartnerCycle() {
                print("✅ Got cycle for forecast: \(cycle.cycleDays?.count ?? 0) days")
                
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                var days: [(Date, FertilityLevel)] = []
                
                for offset in 0..<7 {
                    guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                    
                    // Find the day in cycle_days
                    if let dayData = cycle.cycleDays?.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        days.append((date, FertilityLevel(rawValue: dayData.fertilityLevel) ?? .low))
                    } else {
                        // Calculate from start date
                        let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: cycle.startDate), to: date).day ?? 0
                        let ovulationDay = cycle.cycleLength - 14
                        let fertileStart = ovulationDay - 5
                        let fertileEnd = ovulationDay + 1
                        let dayNumber = daysSinceStart + 1
                        
                        var level: FertilityLevel = .low
                        if dayNumber >= fertileStart && dayNumber <= fertileEnd {
                            if dayNumber == ovulationDay || dayNumber == ovulationDay - 1 {
                                level = .peak
                            } else {
                                level = .high
                            }
                        }
                        days.append((date, level))
                    }
                }
                
                await MainActor.run {
                    partnerForecast = days
                }
                print("✅ Partner forecast loaded: \(days.count) days")
            } else {
                print("⚠️ No cycle found for partner forecast")
            }
        } catch {
            print("❌ Failed to load partner forecast: \(error)")
        }
    }
}

// MARK: - Pregnancy Test Timing

struct PregnancyTestInfoView: View {
    @Bindable var viewModel: AppViewModel
    
    /// Calculate the days past ovulation (DPO)
    var daysPastOvulation: Int? {
        guard let cycle = viewModel.currentCycle else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cycleStart = calendar.startOfDay(for: cycle.startDate)
        
        guard let daysSinceStart = calendar.dateComponents([.day], from: cycleStart, to: today).day else { return nil }
        let currentDay = daysSinceStart + 1
        
        // Ovulation day in the cycle
        let ovulationDay = cycle.estimatedOvulationDay
        
        // DPO = current day - ovulation day (negative = before ovulation)
        let dpo = currentDay - ovulationDay
        return dpo
    }
    
    /// Date when you can take a pregnancy test (8 DPO = earliest reliable)
    var testDate: Date? {
        guard let cycle = viewModel.currentCycle else { return nil }
        
        let calendar = Calendar.current
        let cycleStart = calendar.startOfDay(for: cycle.startDate)
        
        // Test date = cycle start + ovulation day + 8 days
        let testDayNumber = cycle.estimatedOvulationDay + 8
        return calendar.date(byAdding: .day, value: testDayNumber - 1, to: cycleStart)
    }
    
    /// Days until test date
    var daysUntilTest: Int? {
        guard let testDate = testDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: today, to: testDate).day
    }
    
    /// Should we show this view?
    var shouldShow: Bool {
        guard let dpo = daysPastOvulation else { return false }
        // Show from 1 DPO until next period (approximately)
        // Don't show before ovulation (dpo < 0) or very early in cycle
        return dpo >= 1
    }
    
    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 16))
                        .foregroundColor(.momentRose)
                    
                    Text("Zwangerschapstest")
                        .font(.momentSubheadline)
                        .foregroundColor(.momentCharcoal)
                    
                    Spacer()
                }
                
                if let dpo = daysPastOvulation, let daysUntil = daysUntilTest {
                    if daysUntil <= 0 {
                        // Can test now!
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(Color.momentGreen)
                                .frame(width: 8, height: 8)
                            
                            Text("Je kunt nu testen!")
                                .font(.momentCaptionMedium)
                                .foregroundColor(.momentGreen)
                            
                            Text("(\(dpo) DPO)")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                        
                        Text("8+ dagen na ovulatie — hCG is nu detecteerbaar")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                    } else {
                        // Waiting phase
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(Color.momentWarmGray)
                                .frame(width: 8, height: 8)
                            
                            Text("Nog \(daysUntil) \(daysUntil == 1 ? "dag" : "dagen") wachten")
                                .font(.momentCaptionMedium)
                                .foregroundColor(.momentCharcoal)
                            
                            Text("(\(dpo) DPO)")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                        
                        if let date = testDate {
                            Text("Test vanaf \(formatTestDate(date))")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.momentCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.momentSand, lineWidth: 1)
            )
        }
    }
    
    func formatTestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    @Bindable var viewModel: AppViewModel
    var onIntimacyLogged: ((Date, Bool) -> Void)?
    @State private var showingNotifyConfirmation = false
    @State private var isSendingNotification = false
    @State private var notificationSent = false
    
    var isPartnerLinked: Bool {
        viewModel.localCouple?.isLinked == true
    }
    
    var currentFertilityLevel: FertilityLevel {
        viewModel.todaysCycleDay?.fertilityLevel ?? .low
    }
    
    var hasLoggedIntimacyToday: Bool {
        viewModel.todaysCycleDay?.hadIntimacy ?? false
    }
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Quick Actions")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: Spacing.sm) {
                QuickActionButton(
                    icon: "calendar.badge.plus",
                    title: "New Cycle",
                    color: .momentRose
                ) {
                    viewModel.showingLogPeriod = true
                }
                
                // Log intimacy quick action
                QuickActionButton(
                    icon: hasLoggedIntimacyToday ? "heart.fill" : "heart",
                    title: hasLoggedIntimacyToday ? "Logged" : "Log ❤️",
                    color: .momentRose
                ) {
                    let wasLogged = hasLoggedIntimacyToday
                    viewModel.toggleIntimacy(for: Date())
                    // Show toast with the new state (opposite of what it was)
                    onIntimacyLogged?(Date(), !wasLogged)
                }
                
                if viewModel.isInFertileWindow {
                    QuickActionButton(
                        icon: "testtube.2",
                        title: "Log LH",
                        color: .momentTeal,
                        showBadge: viewModel.todaysCycleDay?.lhTestResult == nil
                    ) {
                        viewModel.showingLogLH = true
                    }
                }
                
                if isPartnerLinked {
                    QuickActionButton(
                        icon: notificationSent ? "checkmark.circle.fill" : "bell.badge.fill",
                        title: notificationSent ? "Sent!" : "Notify",
                        color: notificationSent ? .momentGreen : .momentGreen,
                        isLoading: isSendingNotification
                    ) {
                        showingNotifyConfirmation = true
                    }
                    .disabled(isSendingNotification)
                }
            }
        }
        .confirmationDialog(
            "Send update to partner?",
            isPresented: $showingNotifyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send \(currentFertilityLevel.displayName) Fertility Update") {
                sendNotification()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your partner will receive a notification about your current fertility status.")
        }
    }
    
    private func sendNotification() {
        isSendingNotification = true
        
        Task {
            do {
                try await viewModel.notifyPartnerNow()
                await MainActor.run {
                    isSendingNotification = false
                    notificationSent = true
                    
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        notificationSent = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSendingNotification = false
                }
                print("Failed to send notification: \(error)")
            }
        }
    }
}

// MARK: - Partner Quick Actions

struct PartnerQuickActionsView: View {
    @Bindable var viewModel: AppViewModel
    var onIntimacyLogged: ((Date, Bool) -> Void)?
    @State private var hasLoggedIntimacyToday = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Quick Actions")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: Spacing.sm) {
                QuickActionButton(
                    icon: hasLoggedIntimacyToday ? "heart.fill" : "heart",
                    title: hasLoggedIntimacyToday ? "Logged" : "Log ❤️",
                    color: .momentRose,
                    isLoading: isLoading
                ) {
                    logIntimacy()
                }
            }
        }
        .task {
            await checkTodayIntimacy()
        }
    }
    
    func checkTodayIntimacy() async {
        // Check if intimacy was logged today from partner's perspective
        do {
            if let cycle = try await SupabaseService.shared.getPartnerCycle() {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                if let todayData = cycle.cycleDays?.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    await MainActor.run {
                        hasLoggedIntimacyToday = todayData.hadIntimacy ?? false
                    }
                }
            }
        } catch {
            print("Error checking intimacy: \(error)")
        }
    }
    
    func logIntimacy() {
        isLoading = true
        let wasLogged = hasLoggedIntimacyToday
        
        Task {
            do {
                // Toggle: if already logged, remove it; otherwise add it
                let newValue = !wasLogged
                try await SupabaseService.shared.logIntimacy(date: Date(), hadIntimacy: newValue)
                await MainActor.run {
                    hasLoggedIntimacyToday = newValue
                    isLoading = false
                    // Show toast with the new state
                    onIntimacyLogged?(Date(), newValue)
                }
            } catch {
                print("Error logging intimacy: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var showBadge: Bool = false
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(color)
                    }
                    
                    if showBadge && !isLoading {
                        Circle()
                            .fill(Color.momentAmber)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.momentCaptionMedium)
                    .foregroundColor(.momentCharcoal)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(Color.momentCardBackground)
            )
            .momentShadowSubtle()
        }
    }
}

// MARK: - Log Period Sheet

struct LogPeriodSheet: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text("When did your period start?")
                    .font(.momentHeadline)
                    .foregroundColor(.momentCharcoal)
                    .padding(.top, Spacing.lg)
                
                DatePicker(
                    "Period start",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.momentRose)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white)
                )
                .padding(.horizontal, Spacing.md)
                .environment(\.colorScheme, .light)
                
                Spacer()
                
                VStack(spacing: Spacing.sm) {
                    Text("This will start a new cycle and update your predictions")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                        .multilineTextAlignment(.center)
                    
                    Button("Start New Cycle") {
                        viewModel.startNewCycle(startDate: selectedDate)
                    }
                    .buttonStyle(MomentPrimaryButtonStyle())
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showingLogPeriod = false
                    }
                    .foregroundColor(.momentWarmGray)
                }
            }
            .momentBackground()
        }
        .presentationDetents([.large])
    }
}

// MARK: - Log LH Sheet

struct LogLHSheet: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedResult: LHTestResult?
    @State private var showingInfo = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        // Header
                        VStack(spacing: Spacing.xs) {
                            Text("Log LH Test")
                                .font(.momentHeadline)
                                .foregroundColor(.momentCharcoal)
                            
                            HStack(spacing: Spacing.xs) {
                                Text("What was your result today?")
                                    .font(.momentBody)
                                    .foregroundColor(.momentSecondaryText)
                                
                                // "What is this?" inline link
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showingInfo.toggle()
                                    }
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.momentTeal)
                                }
                            }
                        }
                        .padding(.top, Spacing.md)
                        
                        // Expandable info section - shown when tapped
                        if showingInfo {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack {
                                    Text("About LH tests")
                                        .font(.momentSubheadline)
                                        .foregroundColor(.momentCharcoal)
                                    
                                    Spacer()
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showingInfo = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.momentWarmGray)
                                    }
                                }
                                
                                Text("LH tests detect a short hormone surge that often happens shortly before ovulation.")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Logging results is optional. If you choose to log them, Moment can use the signal to refine timing insights over time.")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Moment is not a medical device and does not provide medical advice.")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentWarmGray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.momentTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                            .padding(.horizontal, Spacing.lg)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Result buttons
                        VStack(spacing: Spacing.sm) {
                            LHResultButton(
                                result: .negative,
                                isSelected: selectedResult == .negative,
                                action: { selectedResult = .negative }
                            )
                            
                            LHResultButton(
                                result: .positive,
                                isSelected: selectedResult == .positive,
                                action: { selectedResult = .positive }
                            )
                        }
                        .padding(.horizontal, Spacing.lg)
                        
                        // Positive result info hint
                        if selectedResult == .positive {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.momentGreen)
                                
                                Text("A positive result means ovulation is likely within 24-36 hours")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                        
                        Spacer(minLength: Spacing.xl)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                
                // Log button pinned to bottom
                VStack(spacing: 0) {
                    Divider()
                    Button("Log Result") {
                        if let result = selectedResult {
                            viewModel.logLHTest(result: result)
                        }
                    }
                    .buttonStyle(MomentPrimaryButtonStyle(isEnabled: selectedResult != nil))
                    .disabled(selectedResult == nil)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
                .background(Color.momentBackground)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showingLogLH = false
                    }
                    .foregroundColor(.momentWarmGray)
                }
            }
            .momentBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct LHResultButton: View {
    let result: LHTestResult
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(result.displayName)
                        .font(.momentSubheadline)
                        .foregroundColor(.momentCharcoal)
                    
                    Text(result == .positive ? "Surge detected" : "No surge detected")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.momentGreen : Color.momentMist, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.momentGreen)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.momentCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(isSelected ? Color.momentGreen : Color.clear, lineWidth: 2)
                    )
            )
            .momentShadowSubtle()
        }
    }
}

// MARK: - Temperature Logging View
// Note: Temperature tracking is optional and user-initiated.
// It is OFF by default and never sends notifications or reminders.
// Temperature data is stored but NOT currently used for fertility predictions.
// Future versions may use temperature as a secondary confirmation signal.

struct TemperatureLoggingView: View {
    @Bindable var viewModel: AppViewModel
    @State private var temperatureInput: String = ""
    @State private var hasLoggedToday: Bool = false
    @State private var todaysTemperature: Double?
    @State private var isEditing: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var temperatureUnit: TemperatureUnit {
        viewModel.temperatureUnit
    }
    
    var placeholder: String {
        temperatureUnit == .celsius ? "36.5" : "97.7"
    }
    
    var body: some View {
        MomentCard {
            HStack(spacing: Spacing.md) {
                // Icon
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 20))
                    .foregroundColor(.momentTeal)
                    .frame(width: 28)
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Temperature")
                        .font(.momentSubheadline)
                        .foregroundColor(.momentCharcoal)
                    
                    Text("optional")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                }
                
                Spacer()
                
                // Right side: either logged value or input
                if hasLoggedToday && !isEditing, let temp = todaysTemperature {
                    // Logged state - show value with edit/clear options
                    HStack(spacing: Spacing.xs) {
                        Text(temperatureUnit.format(temp))
                            .font(.momentBodyMedium)
                            .foregroundColor(.momentGreen)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Button {
                            isEditing = true
                            isInputFocused = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.momentTeal.opacity(0.7))
                        }
                        
                        Button {
                            clearTemperature()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.momentWarmGray.opacity(0.6))
                        }
                    }
                } else {
                    // Input state
                    HStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xxs) {
                            TextField(placeholder, text: $temperatureInput)
                                .keyboardType(.decimalPad)
                                .font(.momentBody)
                                .foregroundColor(.momentCharcoal)
                                .focused($isInputFocused)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                            
                            Text(temperatureUnit.displayName)
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.momentMist.opacity(0.5))
                        )
                        
                        Button {
                            logTemperature()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(isValidInput ? .momentTeal : .momentMist)
                        }
                        .disabled(!isValidInput)
                        
                        // Cancel button when editing existing value
                        if isEditing {
                            Button {
                                isEditing = false
                                isInputFocused = false
                                // Reset to original value
                                if let temp = todaysTemperature {
                                    let displayValue = temperatureUnit.displayValue(from: temp)
                                    temperatureInput = String(format: "%.1f", displayValue)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.momentWarmGray.opacity(0.6))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadTodaysTemperature()
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    var isValidInput: Bool {
        guard let value = Double(temperatureInput.replacingOccurrences(of: ",", with: ".")) else {
            return false
        }
        // Valid BBT range: 35-42°C or 95-108°F
        if temperatureUnit == .celsius {
            return value >= 35.0 && value <= 42.0
        } else {
            return value >= 95.0 && value <= 108.0
        }
    }
    
    private func loadTodaysTemperature() {
        if let temp = viewModel.todaysCycleDay?.temperature {
            todaysTemperature = temp
            hasLoggedToday = true
            isEditing = false
            // Show in user's preferred unit
            let displayValue = temperatureUnit.displayValue(from: temp)
            temperatureInput = String(format: "%.1f", displayValue)
        } else {
            hasLoggedToday = false
            todaysTemperature = nil
            temperatureInput = ""
        }
    }
    
    private func logTemperature() {
        guard let value = Double(temperatureInput.replacingOccurrences(of: ",", with: ".")) else { return }
        
        // Convert to Celsius for storage
        let celsius = temperatureUnit.toCelsius(from: value)
        
        viewModel.logTemperature(celsius)
        hasLoggedToday = true
        todaysTemperature = celsius
        isEditing = false
        isInputFocused = false
    }
    
    private func clearTemperature() {
        DataService.shared.removeTemperature(for: Date())
        hasLoggedToday = false
        todaysTemperature = nil
        temperatureInput = ""
        isEditing = false
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
}
