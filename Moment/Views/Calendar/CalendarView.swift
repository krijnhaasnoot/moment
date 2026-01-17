//
//  CalendarView.swift
//  Moment
//
//  Month view with color-coded fertility days
//

import SwiftUI

/*
 SCREEN: Calendar View
 PURPOSE: Visual overview of the cycle with color-coded days
 
 COLOR CODING:
 - Green = Peak fertility (best timing)
 - Teal = High fertility (good timing)
 - Grey = Low fertility (rest period)
 
 PARTNER VIEW:
 - Same colors, but NO menstruation indicators
 - Slightly muted color palette
 - Simpler view without cycle details
*/

struct CalendarView: View {
    @Bindable var viewModel: AppViewModel
    @State private var displayedMonth = Date()
    @State private var partnerCycleDays: [PartnerCycleDay] = []
    @State private var partnerCycleInfo: PartnerCycleInfo?
    @State private var isLoadingPartnerCycle = false
    @State private var selectedDate: Date?
    @State private var showingDayOptions = false
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var isPartner: Bool {
        viewModel.currentUser?.role == .partner
    }
    
    var canLogIntimacy: Bool {
        guard let date = selectedDate else { return false }
        // Can only log for today or past days
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: Date())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Month navigation
                MonthNavigator(displayedMonth: $displayedMonth)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                
                // Calendar grid
                VStack(spacing: Spacing.sm) {
                    // Weekday headers
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.momentCaptionMedium)
                                .foregroundColor(.momentSecondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Days grid
                    if isPartner && isLoadingPartnerCycle {
                        ProgressView()
                            .frame(height: 200)
                    } else {
                        LazyVGrid(columns: columns, spacing: Spacing.sm) {
                            ForEach(daysInMonth, id: \.self) { date in
                                if let date = date {
                                    CalendarDayCell(
                                        date: date,
                                        cycleDay: cycleDayFor(date: date),
                                        partnerCycleDay: partnerCycleDayFor(date: date),
                                        isToday: calendar.isDateInToday(date),
                                        isPartner: isPartner
                                    ) {
                                        // Both woman and partner can tap days
                                        selectedDate = date
                                        showingDayOptions = true
                                    }
                                } else {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.momentCardBackground)
                )
                .momentShadow()
                .padding(.horizontal, Spacing.lg)
                
                // Legend
                CalendarLegend(isPartner: isPartner)
                    .padding(.horizontal, Spacing.lg)
                
                // Cycle info (woman only)
                if !isPartner, let cycle = viewModel.currentCycle {
                    CycleInfoCard(cycle: cycle)
                        .padding(.horizontal, Spacing.lg)
                }
                
                // Partner message
                if isPartner && partnerCycleDays.isEmpty && !isLoadingPartnerCycle {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundColor(.momentWarmGray)
                        
                        Text("Waiting for cycle data")
                            .font(.momentSubheadline)
                            .foregroundColor(.momentCharcoal)
                        
                        Text("Your partner's fertility calendar will appear here once they start tracking")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Spacing.xl)
                    .padding(.horizontal, Spacing.lg)
                }
                
                Spacer(minLength: Spacing.xxl)
            }
        }
        .task {
            if isPartner {
                await loadPartnerCycle()
            }
        }
        .refreshable {
            if isPartner {
                await loadPartnerCycle()
            }
        }
        .confirmationDialog(
            selectedDateTitle,
            isPresented: $showingDayOptions,
            titleVisibility: .visible
        ) {
            if canLogIntimacy {
                let hasIntimacy = isPartner 
                    ? (selectedDate.flatMap { partnerCycleDayFor(date: $0) }?.hadIntimacy ?? false)
                    : (selectedDate.flatMap { cycleDayFor(date: $0) }?.hadIntimacy ?? false)
                
                if hasIntimacy {
                    Button("Remove Intimacy Log", role: .destructive) {
                        if let date = selectedDate {
                            viewModel.logIntimacy(for: date, remove: true)
                        }
                    }
                } else {
                    Button("Log Intimacy ❤️") {
                        if let date = selectedDate {
                            viewModel.logIntimacy(for: date)
                            // Refresh partner data after logging
                            if isPartner {
                                Task {
                                    await loadPartnerCycle()
                                }
                            }
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let date = selectedDate {
                if isPartner {
                    let partnerDay = partnerCycleDayFor(date: date)
                    Text("Fertility: \(partnerDay?.fertilityLevel.displayName ?? "Unknown")")
                } else {
                    let cycleDay = cycleDayFor(date: date)
                    Text("Fertility: \(cycleDay?.fertilityLevel.displayName ?? "Unknown")")
                }
            }
        }
    }
    
    var selectedDateTitle: String {
        guard let date = selectedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        
        let firstWeekday = max(1, min(calendar.firstWeekday, symbols.count))
        let startIndex = firstWeekday - 1
        
        // Safe array slicing
        let endPart = Array(symbols.suffix(from: startIndex))
        let startPart = startIndex > 0 ? Array(symbols.prefix(startIndex)) : []
        
        return endPart + startPart
    }
    
    var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    func cycleDayFor(date: Date) -> CycleDay? {
        guard !isPartner, let cycle = viewModel.currentCycle else { return nil }
        
        // First try exact match from stored days
        if let day = cycle.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return day
        }
        
        // Calculate based on cycle position for dates within cycle range
        let startOfCycle = calendar.startOfDay(for: cycle.startDate)
        let checkDate = calendar.startOfDay(for: date)
        
        guard let daysSinceStart = calendar.dateComponents([.day], from: startOfCycle, to: checkDate).day else {
            return nil
        }
        
        // Only show for dates within this cycle (0 to cycleLength-1)
        guard daysSinceStart >= 0 && daysSinceStart < cycle.cycleLength else {
            return nil
        }
        
        // If we have stored days, use them by index
        if daysSinceStart < cycle.days.count {
            return cycle.days[daysSinceStart]
        }
        
        // Otherwise calculate fertility level
        let dayNumber = daysSinceStart + 1
        let isMenstruation = dayNumber <= 5
        
        var fertilityLevel: FertilityLevel = .low
        if dayNumber >= cycle.fertileWindowStart && dayNumber <= cycle.fertileWindowEnd {
            if dayNumber == cycle.estimatedOvulationDay || dayNumber == cycle.estimatedOvulationDay - 1 {
                fertilityLevel = .peak
            } else {
                fertilityLevel = .high
            }
        }
        
        return CycleDay(date: date, fertilityLevel: fertilityLevel, isMenstruation: isMenstruation)
    }
    
    func partnerCycleDayFor(date: Date) -> PartnerCycleDay? {
        guard isPartner else { return nil }
        
        // First try to find an exact match from stored days
        if let day = partnerCycleDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return day
        }
        
        // Calculate based on cycle position for dates within cycle range
        guard let cycleInfo = partnerCycleInfo else { return nil }
        
        let startOfCycle = calendar.startOfDay(for: cycleInfo.startDate)
        let checkDate = calendar.startOfDay(for: date)
        
        guard let daysSinceStart = calendar.dateComponents([.day], from: startOfCycle, to: checkDate).day else {
            return nil
        }
        
        // Only show for dates within this cycle (0 to cycleLength-1)
        guard daysSinceStart >= 0 && daysSinceStart < cycleInfo.cycleLength else {
            return nil
        }
        
        // Calculate fertility level based on cycle day
        let dayNumber = daysSinceStart + 1
        let ovulationDay = cycleInfo.cycleLength - 14
        let fertileStart = ovulationDay - 5
        let fertileEnd = ovulationDay + 1
        
        var fertilityLevel: FertilityLevel = .low
        if dayNumber >= fertileStart && dayNumber <= fertileEnd {
            if dayNumber == ovulationDay || dayNumber == ovulationDay - 1 {
                fertilityLevel = .peak
            } else {
                fertilityLevel = .high
            }
        }
        
        return PartnerCycleDay(date: date, fertilityLevel: fertilityLevel, lhTestResult: nil, hadIntimacy: false)
    }
    
    func loadPartnerCycle() async {
        isLoadingPartnerCycle = true
        do {
            if let cycle = try await SupabaseService.shared.getPartnerCycle() {
                let days = cycle.cycleDays?.map { day in
                    PartnerCycleDay(
                        date: day.date,
                        fertilityLevel: FertilityLevel(rawValue: day.fertilityLevel) ?? .low,
                        lhTestResult: day.lhTestResult.flatMap { LHTestResult(rawValue: $0) },
                        hadIntimacy: day.hadIntimacy ?? false
                    )
                } ?? []
                
                // Store cycle info for calculating future days
                let cycleInfo = PartnerCycleInfo(
                    startDate: cycle.startDate,
                    cycleLength: cycle.cycleLength
                )
                
                await MainActor.run {
                    partnerCycleDays = days
                    partnerCycleInfo = cycleInfo
                }
            }
        } catch {
            print("Failed to load partner cycle: \(error)")
        }
        await MainActor.run {
            isLoadingPartnerCycle = false
        }
    }
}

// Partner cycle metadata for calculating future days
struct PartnerCycleInfo {
    let startDate: Date
    let cycleLength: Int
}

// Partner-safe cycle day (no menstruation data)
struct PartnerCycleDay {
    let date: Date
    let fertilityLevel: FertilityLevel
    let lhTestResult: LHTestResult?
    var hadIntimacy: Bool = false
}

// MARK: - Month Navigator

struct MonthNavigator: View {
    @Binding var displayedMonth: Date
    
    private let calendar = Calendar.current
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    var body: some View {
        HStack {
            Button {
                withAnimation(.momentSpring) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.momentWarmGray)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text(monthString)
                .font(.momentSubheadline)
                .foregroundColor(.momentCharcoal)
            
            Spacer()
            
            Button {
                withAnimation(.momentSpring) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.momentWarmGray)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let cycleDay: CycleDay?
    let partnerCycleDay: PartnerCycleDay?
    let isToday: Bool
    let isPartner: Bool
    var onTap: (() -> Void)? = nil
    
    private let calendar = Calendar.current
    
    var dayNumber: String {
        String(calendar.component(.day, from: date))
    }
    
    var fertilityLevel: FertilityLevel? {
        if isPartner {
            return partnerCycleDay?.fertilityLevel
        } else {
            return cycleDay?.fertilityLevel
        }
    }
    
    var hadIntimacy: Bool {
        if isPartner {
            return partnerCycleDay?.hadIntimacy ?? false
        }
        return cycleDay?.hadIntimacy ?? false
    }
    
    var backgroundColor: Color {
        // Woman view
        if !isPartner {
            guard let cycleDay = cycleDay else { return Color.clear }
            
            if cycleDay.isMenstruation {
                return Color.momentRose.opacity(0.3)
            }
            
            let color = Color.fertilityColor(for: cycleDay.fertilityLevel)
            return color.opacity(cycleDay.fertilityLevel == .low ? 0.2 : 0.4)
        }
        
        // Partner view
        guard let level = partnerCycleDay?.fertilityLevel else {
            return Color.clear
        }
        
        let color = Color.partnerFertilityColor(for: level)
        return color.opacity(level == .low ? 0.2 : 0.4)
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(backgroundColor)
                
                // Day number
                Text(dayNumber)
                    .font(.momentBodySmall)
                    .foregroundColor(isToday ? .momentCharcoal : .momentWarmGray)
                
                // Today indicator
                if isToday {
                    Circle()
                        .stroke(Color.momentCharcoal, lineWidth: 2)
                        .padding(4)
                }
                
                // Heart indicator for intimacy (both roles)
                if hadIntimacy {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.momentRose)
                        .offset(x: 10, y: 10)
                }
                
                // LH positive indicator (woman only)
                if !isPartner, cycleDay?.lhTestResult == .positive {
                    Circle()
                        .fill(Color.momentGreen)
                        .frame(width: 6, height: 6)
                        .offset(x: 10, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fill)
    }
}

// MARK: - Calendar Legend

struct CalendarLegend: View {
    let isPartner: Bool
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            LegendItem(
                color: isPartner ? .momentPartnerGreen : .momentGreen,
                label: "Peak"
            )
            
            LegendItem(
                color: isPartner ? .momentPartnerTeal : .momentTeal,
                label: "High"
            )
            
            LegendItem(
                color: isPartner ? .momentPartnerMist : .momentMist,
                label: "Low"
            )
            
            if !isPartner {
                LegendItem(
                    color: .momentRose.opacity(0.6),
                    label: "Period"
                )
                
                // Heart legend item
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.momentRose)
                    
                    Text("Intimacy")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                }
            }
            
            Spacer()
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(label)
                .font(.momentCaption)
                .foregroundColor(.momentSecondaryText)
        }
    }
}

// MARK: - Cycle Info Card

struct CycleInfoCard: View {
    let cycle: Cycle
    
    private let calendar = Calendar.current
    
    var currentDayNumber: Int {
        let days = calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return days + 1
    }
    
    var predictedPeriodDate: Date? {
        calendar.date(byAdding: .day, value: cycle.cycleLength, to: cycle.startDate)
    }
    
    var daysUntilPeriod: Int {
        guard let predicted = predictedPeriodDate else { return 0 }
        return calendar.dateComponents([.day], from: Date(), to: predicted).day ?? 0
    }
    
    var body: some View {
        MomentCard {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Cycle Day")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    Text("\(currentDayNumber)")
                        .font(.momentHeadline)
                        .foregroundColor(.momentCharcoal)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Cycle Length")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    Text("\(cycle.cycleLength) days")
                        .font(.momentHeadline)
                        .foregroundColor(.momentCharcoal)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Next Period")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    Text(daysUntilPeriod > 0 ? "~\(daysUntilPeriod) days" : "Soon")
                        .font(.momentHeadline)
                        .foregroundColor(.momentCharcoal)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    CalendarView(viewModel: AppViewModel())
}
