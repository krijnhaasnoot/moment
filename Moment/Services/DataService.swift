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
            // Regenerate days if empty (can happen after encoding/decoding)
            if cycle.days.isEmpty {
                cycle.generateDays()
                // Save the regenerated cycle
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
        // Archive previous active cycle
        var allCycles = cycles
        for i in allCycles.indices {
            if allCycles[i].isActive {
                allCycles[i].isActive = false
                allCycles[i].endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)
            }
        }
        
        // Calculate average cycle length from history
        let averageLength = calculateAverageCycleLength()
        
        var newCycle = Cycle(userId: currentUser?.id ?? UUID(), startDate: startDate, cycleLength: averageLength)
        newCycle.generateDays()
        
        allCycles.insert(newCycle, at: 0)
        cycles = allCycles
        
        return newCycle
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
        guard var cycle = currentCycle else { return }
        
        let calendar = Calendar.current
        if let dayIndex = cycle.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            cycle.days[dayIndex].hadIntimacy = true
            cycle.days[dayIndex].intimacyLoggedAt = Date()
            currentCycle = cycle
        }
    }
    
    func removeIntimacy(for date: Date) {
        guard var cycle = currentCycle else { return }
        
        let calendar = Calendar.current
        if let dayIndex = cycle.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            cycle.days[dayIndex].hadIntimacy = false
            cycle.days[dayIndex].intimacyLoggedAt = nil
            currentCycle = cycle
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
