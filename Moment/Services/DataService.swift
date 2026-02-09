//
//  DataService.swift
//  Moment
//
//  Local data persistence using UserDefaults for MVP
//

import Foundation

@Observable
final class DataService {
    static let shared = DataService()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let currentUser = "currentUser"
        static let couple = "couple"
        static let cycles = "cycles"
        static let onboardingComplete = "onboardingComplete"
        static let hasSeenWelcome = "hasSeenWelcome"
    }
    
    // MARK: - User
    
    var currentUser: User? {
        get {
            guard let data = userDefaults.data(forKey: Keys.currentUser) else { return nil }
            return try? JSONDecoder().decode(User.self, from: data)
        }
        set {
            if let newValue = newValue {
                let data = try? JSONEncoder().encode(newValue)
                userDefaults.set(data, forKey: Keys.currentUser)
            } else {
                userDefaults.removeObject(forKey: Keys.currentUser)
            }
        }
    }
    
    // MARK: - Couple
    
    var couple: LocalCouple? {
        get {
            guard let data = userDefaults.data(forKey: Keys.couple) else { return nil }
            return try? JSONDecoder().decode(LocalCouple.self, from: data)
        }
        set {
            if let newValue = newValue {
                let data = try? JSONEncoder().encode(newValue)
                userDefaults.set(data, forKey: Keys.couple)
            } else {
                userDefaults.removeObject(forKey: Keys.couple)
            }
        }
    }
    
    // MARK: - Cycles
    
    var cycles: [Cycle] {
        get {
            guard let data = userDefaults.data(forKey: Keys.cycles) else { return [] }
            return (try? JSONDecoder().decode([Cycle].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: Keys.cycles)
        }
    }
    
    var currentCycle: Cycle? {
        get {
            guard var cycle = cycles.first(where: { $0.isActive }) else { return nil }
            
            let calendar = Calendar.current
            var needsUpdate = false
            
            // Check if start date needs normalization (not at midnight)
            let normalizedStart = calendar.startOfDay(for: cycle.startDate)
            if cycle.startDate != normalizedStart {
                cycle.startDate = normalizedStart
                needsUpdate = true
            }
            
            // Regenerate days if empty or if dates need normalization
            if cycle.days.isEmpty {
                cycle.generateDays()
                needsUpdate = true
            } else if let firstDay = cycle.days.first,
                      firstDay.date != calendar.startOfDay(for: firstDay.date) {
                // Days have non-normalized dates, regenerate while preserving intimacy/LH data
                let oldDays = cycle.days
                cycle.generateDays()
                // Restore intimacy and LH data from old days by matching day index
                for i in 0..<min(oldDays.count, cycle.days.count) {
                    cycle.days[i].hadIntimacy = oldDays[i].hadIntimacy
                    cycle.days[i].intimacyLoggedAt = oldDays[i].intimacyLoggedAt
                    cycle.days[i].lhTestResult = oldDays[i].lhTestResult
                    cycle.days[i].lhTestLoggedAt = oldDays[i].lhTestLoggedAt
                    cycle.days[i].notes = oldDays[i].notes
                }
                needsUpdate = true
            }
            
            // Save if we made changes
            if needsUpdate {
                var allCycles = cycles
                if let index = allCycles.firstIndex(where: { $0.id == cycle.id }) {
                    allCycles[index] = cycle
                    self.cycles = allCycles
                }
            }
            
            return cycle
        }
        set {
            if let newCycle = newValue {
                var allCycles = cycles
                
                // Deactivate other active cycles if this one is active
                if newCycle.isActive {
                    for i in allCycles.indices {
                        if allCycles[i].isActive && allCycles[i].id != newCycle.id {
                            allCycles[i].isActive = false
                        }
                    }
                }
                
                // Update or insert the new cycle
                if let index = allCycles.firstIndex(where: { $0.id == newCycle.id }) {
                    allCycles[index] = newCycle
                } else {
                    allCycles.insert(newCycle, at: 0)
                }
                cycles = allCycles
            }
        }
    }
    
    // MARK: - Onboarding
    
    var isOnboardingComplete: Bool {
        get { userDefaults.bool(forKey: Keys.onboardingComplete) }
        set { userDefaults.set(newValue, forKey: Keys.onboardingComplete) }
    }
    
    var hasSeenWelcome: Bool {
        get { userDefaults.bool(forKey: Keys.hasSeenWelcome) }
        set { userDefaults.set(newValue, forKey: Keys.hasSeenWelcome) }
    }
    
    // MARK: - Methods
    
    func createUser(name: String, role: UserRole) -> User {
        let user = User(name: name, role: role)
        currentUser = user
        
        if role == .woman {
            let newCouple = LocalCouple(womanId: user.id)
            self.couple = newCouple
            var updatedUser = user
            updatedUser.coupleId = newCouple.id
            currentUser = updatedUser
        }
        
        return user
    }
    
    func joinCouple(withCode code: String, partnerName: String) -> Bool {
        // In MVP, we simulate joining by just setting up the partner locally
        // In production, this would verify against a backend
        guard var existingCouple = couple else { return false }
        
        let partner = User(name: partnerName, role: .partner, coupleId: existingCouple.id)
        existingCouple.partnerId = partner.id
        existingCouple.isLinked = true
        couple = existingCouple
        currentUser = partner
        
        return true
    }
    
    func startNewCycle(startDate: Date) -> Cycle {
        // Archive previous active cycle and learn from LH data
        var allCycles = cycles
        var previousCycle: Cycle?
        
        for i in allCycles.indices {
            if allCycles[i].isActive {
                previousCycle = allCycles[i]
                allCycles[i].isActive = false
                allCycles[i].endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)
            }
        }
        
        // Learn from previous cycle's LH data (if available)
        if let previous = previousCycle {
            recalibrateLutealPhase(previousCycle: previous, newCycleStartDate: startDate)
        }
        
        // Calculate average cycle length from history
        let averageLength = calculateAverageCycleLength()
        
        // Use personalized luteal length (or default 14)
        let lutealLength = currentUser?.lutealSamples ?? 0 > 0
            ? currentUser?.averageLutealLength ?? 14
            : 14
        
        var newCycle = Cycle(
            userId: currentUser?.id ?? UUID(),
            startDate: startDate,
            cycleLength: averageLength,
            lutealLength: lutealLength
        )
        newCycle.generateDays()
        
        allCycles.insert(newCycle, at: 0)
        cycles = allCycles
        
        return newCycle
    }
    
    // MARK: - Luteal Phase Learning
    
    /// Learn from LH test data when a new cycle starts
    /// This improves future ovulation estimates based on actual LH surge → period intervals
    ///
    /// Algorithm:
    /// 1. Find the first LH positive in the previous cycle
    /// 2. Calculate observed luteal length = days from LH positive to new cycle start - 1
    /// 3. Update rolling average with the new observation (capped at 6 samples)
    ///
    /// Edge cases handled:
    /// - No LH data → skip learning
    /// - Irregular cycle (<21 or >40 days) → skip learning
    /// - Multiple LH positives → use first only (LH surge peaks once)
    func recalibrateLutealPhase(previousCycle: Cycle, newCycleStartDate: Date) {
        guard var user = currentUser, user.role == .woman else { return }
        
        // Find the FIRST LH positive day in the previous cycle
        let lhPositiveDays = previousCycle.days
            .filter { $0.lhTestResult == .positive }
            .sorted { $0.date < $1.date }
        
        guard let firstLHPositive = lhPositiveDays.first else {
            // No LH data → cannot learn, skip silently
            return
        }
        
        // Calculate observed luteal length
        // Ovulation typically occurs 24-36h after LH surge, so:
        // lutealLength ≈ (new cycle start) - (LH positive date) - 1
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstLHPositive.date),
            to: calendar.startOfDay(for: newCycleStartDate)
        ).day ?? 14
        
        let observedLutealLength = daysBetween - 1
        
        // Validate: skip if cycle seems irregular or luteal length is outside normal range
        let cycleLength = calendar.dateComponents(
            [.day],
            from: previousCycle.startDate,
            to: newCycleStartDate
        ).day ?? 28
        
        // Skip learning for irregular cycles (too short or too long)
        guard cycleLength >= 21 && cycleLength <= 40 else {
            print("⚠️ Skipping luteal learning: irregular cycle length (\(cycleLength) days)")
            return
        }
        
        // Clamp to physiologically plausible range (8-18 days)
        let clampedLutealLength = max(8, min(observedLutealLength, 18))
        
        // Update rolling average (cap at 6 samples for recent-data weighting)
        let maxSamples = 6
        let cappedCount = min(user.lutealSamples, maxSamples - 1)
        
        let newAverage = (user.averageLutealLength * cappedCount + clampedLutealLength) / (cappedCount + 1)
        let newSampleCount = min(user.lutealSamples + 1, maxSamples)
        
        // Persist updated learning
        user.averageLutealLength = newAverage
        user.lutealSamples = newSampleCount
        currentUser = user
        
        print("📊 Luteal learning: observed=\(observedLutealLength)d, clamped=\(clampedLutealLength)d, newAvg=\(newAverage)d, samples=\(newSampleCount)")
    }
    
    func calculateAverageCycleLength() -> Int {
        let completedCycles = cycles.filter { !$0.isActive && $0.endDate != nil }
        guard !completedCycles.isEmpty else { return 28 }
        
        let lengths = completedCycles.compactMap { cycle -> Int? in
            guard let endDate = cycle.endDate else { return nil }
            return Calendar.current.dateComponents([.day], from: cycle.startDate, to: endDate).day
        }
        
        guard !lengths.isEmpty else { return 28 }
        return lengths.reduce(0, +) / lengths.count
    }
    
    func logLHTest(result: LHTestResult, for date: Date = Date()) {
        guard var cycle = currentCycle else { return }
        
        let calendar = Calendar.current
        if let dayIndex = cycle.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            cycle.days[dayIndex].lhTestResult = result
            cycle.days[dayIndex].lhTestLoggedAt = Date()
            
            if result == .positive {
                cycle.days[dayIndex].fertilityLevel = .peak
                // Also mark next day as peak if within cycle
                if dayIndex + 1 < cycle.days.count {
                    cycle.days[dayIndex + 1].fertilityLevel = .peak
                }
            }
            
            currentCycle = cycle
        }
    }
    
    func logIntimacy(for date: Date = Date()) {
        guard var cycle = currentCycle else {
            print("❌ logIntimacy: No current cycle")
            return
        }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startOfCycle = calendar.startOfDay(for: cycle.startDate)
        let today = calendar.startOfDay(for: Date())
        
        // Calculate day offset from cycle start
        guard let dayOffset = calendar.dateComponents([.day], from: startOfCycle, to: targetDate).day else {
            print("❌ logIntimacy: Could not calculate day offset")
            return
        }
        
        // Only allow logging for past/today days
        guard targetDate <= today else {
            print("⚠️ logIntimacy: Cannot log for future date")
            return
        }
        
        // Days before cycle start - extend cycle backwards
        if dayOffset < 0 {
            let daysToAdd = abs(dayOffset)
            var newDays: [CycleDay] = []
            
            // Create days from target date to day before cycle start
            for i in 0..<daysToAdd {
                guard let dayDate = calendar.date(byAdding: .day, value: i, to: targetDate) else { continue }
                var newDay = CycleDay(date: dayDate, fertilityLevel: .low, isMenstruation: false)
                
                // Set intimacy for the first day (target date)
                if i == 0 {
                    newDay.hadIntimacy = true
                    newDay.intimacyLoggedAt = Date()
                }
                newDays.append(newDay)
            }
            
            // Prepend new days to existing days
            cycle.days = newDays + cycle.days
            // Update cycle start date
            cycle.startDate = targetDate
            currentCycle = cycle
            print("✅ Extended cycle backwards and logged intimacy for \(targetDate)")
            return
        }
        
        // If day exists in array, update it
        if dayOffset < cycle.days.count {
            cycle.days[dayOffset].hadIntimacy = true
            cycle.days[dayOffset].intimacyLoggedAt = Date()
            currentCycle = cycle
            print("✅ Local intimacy logged for day \(dayOffset + 1) of cycle (index \(dayOffset))")
        } else {
            // Day is beyond stored array (extended cycle) - extend the array
            // Fill in any missing days between current array end and target day
            let currentCount = cycle.days.count
            for i in currentCount...dayOffset {
                guard let dayDate = calendar.date(byAdding: .day, value: i, to: startOfCycle) else { continue }
                let dayNumber = i + 1
                
                // Calculate fertility for extended days (typically low after cycle length)
                var fertilityLevel: FertilityLevel = .low
                if dayNumber >= cycle.fertileWindowStart && dayNumber <= cycle.fertileWindowEnd {
                    if dayNumber == cycle.estimatedOvulationDay || dayNumber == cycle.estimatedOvulationDay - 1 {
                        fertilityLevel = .peak
                    } else {
                        fertilityLevel = .high
                    }
                }
                
                var newDay = CycleDay(date: dayDate, fertilityLevel: fertilityLevel, isMenstruation: false)
                
                // Set intimacy for the target day
                if i == dayOffset {
                    newDay.hadIntimacy = true
                    newDay.intimacyLoggedAt = Date()
                }
                
                cycle.days.append(newDay)
            }
            currentCycle = cycle
            print("✅ Extended cycle and logged intimacy for day \(dayOffset + 1) (index \(dayOffset))")
        }
    }
    
    func removeIntimacy(for date: Date) {
        guard var cycle = currentCycle else {
            print("❌ removeIntimacy: No current cycle")
            return
        }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startOfCycle = calendar.startOfDay(for: cycle.startDate)
        
        // Calculate day offset from cycle start
        guard let dayOffset = calendar.dateComponents([.day], from: startOfCycle, to: targetDate).day else {
            print("❌ removeIntimacy: Could not calculate day offset")
            return
        }
        
        // Update the day at the calculated offset (only if it exists)
        if dayOffset >= 0 && dayOffset < cycle.days.count {
            cycle.days[dayOffset].hadIntimacy = false
            cycle.days[dayOffset].intimacyLoggedAt = nil
            currentCycle = cycle
            print("✅ Local intimacy removed for day \(dayOffset + 1) of cycle (index \(dayOffset))")
        } else {
            // Day doesn't exist in array - nothing to remove
            print("⚠️ removeIntimacy: Day \(dayOffset) not in stored days (0..<\(cycle.days.count))")
        }
    }
    
    // MARK: - Temperature Tracking (Optional)
    // Note: Temperature is stored but NOT currently used for fertility predictions.
    // Future versions may use temperature as a secondary confirmation signal.
    
    /// Log temperature for a given date
    /// Temperature should be in Celsius (converted before calling this method)
    func logTemperature(_ temperatureCelsius: Double, for date: Date = Date()) {
        guard var cycle = currentCycle else {
            print("❌ logTemperature: No current cycle")
            return
        }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startOfCycle = calendar.startOfDay(for: cycle.startDate)
        
        // Calculate day offset from cycle start
        guard let dayOffset = calendar.dateComponents([.day], from: startOfCycle, to: targetDate).day else {
            print("❌ logTemperature: Could not calculate day offset")
            return
        }
        
        // Update the day at the calculated offset (only if it exists)
        if dayOffset >= 0 && dayOffset < cycle.days.count {
            cycle.days[dayOffset].temperature = temperatureCelsius
            cycle.days[dayOffset].temperatureLoggedAt = Date()
            currentCycle = cycle
            print("✅ Temperature logged: \(temperatureCelsius)°C for day \(dayOffset + 1)")
        } else {
            print("⚠️ logTemperature: Day \(dayOffset) not in stored days")
        }
    }
    
    /// Remove temperature for a given date
    func removeTemperature(for date: Date) {
        guard var cycle = currentCycle else {
            print("❌ removeTemperature: No current cycle")
            return
        }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startOfCycle = calendar.startOfDay(for: cycle.startDate)
        
        // Calculate day offset from cycle start
        guard let dayOffset = calendar.dateComponents([.day], from: startOfCycle, to: targetDate).day else {
            print("❌ removeTemperature: Could not calculate day offset")
            return
        }
        
        // Update the day at the calculated offset (only if it exists)
        if dayOffset >= 0 && dayOffset < cycle.days.count {
            cycle.days[dayOffset].temperature = nil
            cycle.days[dayOffset].temperatureLoggedAt = nil
            currentCycle = cycle
            print("✅ Temperature removed for day \(dayOffset + 1)")
        }
    }
    
    func getTodaysCycleDay() -> CycleDay? {
        guard let cycle = currentCycle else { return nil }
        let today = Date()
        let calendar = Calendar.current
        
        // First try exact date match
        if let day = cycle.days.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return day
        }
        
        // Fallback: calculate day index from start date
        let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: cycle.startDate), to: calendar.startOfDay(for: today)).day ?? 0
        let dayIndex = daysSinceStart
        
        if dayIndex >= 0 && dayIndex < cycle.days.count {
            return cycle.days[dayIndex]
        }
        
        return nil
    }
    
    func isInFertileWindow() -> Bool {
        guard let today = getTodaysCycleDay() else { return false }
        return today.fertilityLevel == .high || today.fertilityLevel == .peak
    }
    
    func resetAllData() {
        userDefaults.removeObject(forKey: Keys.currentUser)
        userDefaults.removeObject(forKey: Keys.couple)
        userDefaults.removeObject(forKey: Keys.cycles)
        userDefaults.removeObject(forKey: Keys.onboardingComplete)
        userDefaults.removeObject(forKey: Keys.hasSeenWelcome)
    }
}
