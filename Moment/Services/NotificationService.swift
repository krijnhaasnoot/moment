//
//  NotificationService.swift
//  Moment
//
//  Handles all push notification scheduling and logic
//

import Foundation
import UserNotifications

/*
 NOTIFICATION LOGIC:
 
 1. DAILY FERTILITY NOTIFICATION (only on HIGH/PEAK days)
    - Scheduled at 8:00 AM
    - Woman receives notification ONLY on high/peak days (no boring "low" messages)
    - Partner receives only if fertility is HIGH or PEAK
    - Content based on woman's chosen notification tone
    - Messages are varied to keep things fresh
 
 2. LH POSITIVE ALERT (immediate, one-time)
    - Triggered immediately when woman logs positive LH
    - Both partners receive
    - This is the ONLY exception to the 1-notification-per-day rule
 
 3. PREGNANCY TEST REMINDER (8 days after peak)
    - Sent once, 8 days after peak fertility (typical implantation window)
    - Only to women
 
 NOTIFICATION RULES:
 - NO notifications on low fertility days
 - Partner NEVER sees: raw cycle data, menstruation, symptoms
 - Partner ONLY sees: fertility level (color) and actionable message
 - Woman controls notification tone for partner
*/

@Observable
final class NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let dataService = DataService.shared
    
    // Track sent notifications to enforce daily limit
    private var lastDailyNotificationDate: Date?
    
    // MARK: - Message Pools (Varied messages)
    
    private let womanHighMessages = [
        "Je vruchtbare periode is begonnen 🌸",
        "Fertility window open — timing is goed de komende dagen",
        "Hoge vruchtbaarheid vandaag — je lichaam bereidt zich voor",
        "De komende dagen zijn gunstig ✨",
        "Je bent in je vruchtbare venster aangekomen",
        "Goede timing de komende 3-4 dagen",
    ]
    
    private let womanPeakMessages = [
        "Piek vruchtbaarheid vandaag — je meest vruchtbare moment 🎯",
        "Dit is het! Je meest vruchtbare dag",
        "Ovulatie komt eraan — ideale timing vandaag",
        "Peak fertility — nu of nooit deze cyclus ⭐",
        "Je lichaam is klaar — vandaag is de dag",
        "Maximale vruchtbaarheid bereikt",
    ]
    
    private let partnerHighExplicitMessages = [
        "Vruchtbare periode begonnen — goed moment om te connecten",
        "High fertility — de komende dagen zijn gunstig",
        "Het vruchtbare venster is open 💫",
        "Timing is goed deze week",
    ]
    
    private let partnerHighDiscreetMessages = [
        "Goed moment om te connecten met je partner",
        "Quality time deze week ✨",
        "Mooie dagen om samen door te brengen",
        "Check in met je partner vandaag",
    ]
    
    private let partnerPeakExplicitMessages = [
        "Peak fertility vandaag — het moment is daar 🎯",
        "Dit is de dag — maximale kans",
        "Ideale timing — vandaag telt het meest",
        "Nu of nooit deze cyclus ⭐",
    ]
    
    private let partnerPeakDiscreetMessages = [
        "Belangrijk moment — neem de tijd samen",
        "Vandaag is een bijzondere dag 💫",
        "Check-in tijd — maak er iets moois van",
        "Quality time vandaag ✨",
    ]
    
    private let pregnancyTestMessages = [
        "Het is tijd — je kunt vandaag een zwangerschapstest doen 🤞",
        "8 dagen na ovulatie — een goede dag voor een test",
        "Testdag! Veel succes 🍀",
    ]
    
    private func randomMessage(from pool: [String]) -> String {
        pool.randomElement() ?? pool[0]
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Scheduling
    
    func scheduleDailyNotifications() {
        guard let user = dataService.currentUser else { return }
        
        // Cancel existing notifications
        notificationCenter.removeAllPendingNotificationRequests()
        
        if user.role == .woman {
            scheduleWomanDailyNotification()
        } else {
            schedulePartnerDailyNotification()
        }
    }
    
    private func scheduleWomanDailyNotification() {
        guard let today = dataService.getTodaysCycleDay() else { return }
        
        // ONLY notify on HIGH or PEAK days — no more boring "low fertility" messages
        guard today.fertilityLevel != .low else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Moment"
        content.sound = .default
        
        switch today.fertilityLevel {
        case .peak:
            content.body = randomMessage(from: womanPeakMessages)
        case .high:
            content.body = randomMessage(from: womanHighMessages)
        case .low:
            return // No notification for low fertility
        }
        
        // Schedule for 8 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "daily_woman", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    private func schedulePartnerDailyNotification() {
        guard let today = dataService.getTodaysCycleDay() else { return }
        guard today.fertilityLevel != .low else { return } // Partner only notified on high/peak
        
        guard let user = dataService.currentUser else { return }
        let tone = user.notificationTone
        
        let content = UNMutableNotificationContent()
        content.title = "Moment"
        content.sound = .default
        
        switch today.fertilityLevel {
        case .peak:
            content.body = tone == .explicit 
                ? randomMessage(from: partnerPeakExplicitMessages) 
                : randomMessage(from: partnerPeakDiscreetMessages)
        case .high:
            content.body = tone == .explicit 
                ? randomMessage(from: partnerHighExplicitMessages) 
                : randomMessage(from: partnerHighDiscreetMessages)
        case .low:
            return // No notification for low fertility
        }
        
        // Schedule for 8 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "daily_partner", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    // MARK: - Immediate Notifications
    
    func sendLHPositiveAlert() {
        guard let user = dataService.currentUser else { return }
        let tone = user.notificationTone
        
        // Notification for woman
        let womanContent = UNMutableNotificationContent()
        womanContent.title = "LH Surge Detected"
        womanContent.body = "Ovulatie waarschijnlijk binnen 24-36 uur"
        womanContent.sound = .default
        
        let womanRequest = UNNotificationRequest(
            identifier: "lh_positive_woman_\(Date().timeIntervalSince1970)",
            content: womanContent,
            trigger: nil // Immediate
        )
        
        // Notification for partner (in production, sent via backend)
        let partnerContent = UNMutableNotificationContent()
        partnerContent.title = "Moment"
        partnerContent.sound = .default
        
        if tone == .explicit {
            partnerContent.body = "Peak fertility gedetecteerd — beste timing vandaag 🎯"
        } else {
            partnerContent.body = "Belangrijk moment — connect met je partner 💫"
        }
        
        let partnerRequest = UNNotificationRequest(
            identifier: "lh_positive_partner_\(Date().timeIntervalSince1970)",
            content: partnerContent,
            trigger: nil // Immediate
        )
        
        // In MVP, we send both locally. In production, partner notification goes via backend
        notificationCenter.add(womanRequest)
        notificationCenter.add(partnerRequest)
        
        // Schedule pregnancy test reminder for 8 days from now
        schedulePregnancyTestReminder()
    }
    
    func sendCycleStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Nieuwe Cyclus Gestart"
        content.body = "Je voorspellingen zijn bijgewerkt"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "cycle_start_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Pregnancy Test Reminder
    
    /// Schedule a reminder to take a pregnancy test ~8 days after ovulation
    /// This is when implantation typically occurs and hCG becomes detectable
    func schedulePregnancyTestReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Moment"
        content.body = randomMessage(from: pregnancyTestMessages)
        content.sound = .default
        
        // Schedule for 8 days from now at 9 AM
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        if let futureDate = Calendar.current.date(byAdding: .day, value: 8, to: Date()) {
            dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: futureDate)
        }
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pregnancy_test_reminder",
            content: content,
            trigger: trigger
        )
        
        // Remove any existing pregnancy test reminder first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["pregnancy_test_reminder"])
        notificationCenter.add(request)
        
        print("📅 Scheduled pregnancy test reminder for 8 days from now")
    }
    
    /// Cancel pregnancy test reminder (e.g., when new period starts)
    func cancelPregnancyTestReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["pregnancy_test_reminder"])
        print("🗑️ Cancelled pregnancy test reminder")
    }
}
