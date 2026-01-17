//
//  NotificationService.swift
//  Moment
//
//  Handles all push notification scheduling and logic
//

import Foundation
import UserNotifications

/*
 NOTIFICATION LOGIC (Pseudocode):
 
 1. DAILY FERTILITY NOTIFICATION (max 1 per day)
    - Scheduled at 8:00 AM
    - Woman always receives her fertility status
    - Partner receives only if fertility is HIGH or PEAK
    - Content based on woman's chosen notification tone
 
 2. LH TEST REMINDER (during fertile window only)
    - Scheduled at 7:00 PM if no LH test logged today
    - Woman only
    - "Don't forget to log your LH test today"
 
 3. LH POSITIVE ALERT (immediate, one-time)
    - Triggered immediately when woman logs positive LH
    - Both partners receive
    - This is the ONLY exception to the 1-notification-per-day rule
    - Content: "Peak fertility detected" (explicit) or "Special moment today" (discreet)
 
 NOTIFICATION RULES:
 - Partner NEVER sees: raw cycle data, menstruation, symptoms
 - Partner ONLY sees: fertility level (color) and actionable message
 - Woman controls notification tone for partner
 - Max 1 scheduled notification per day + 1 LH positive alert
*/

@Observable
final class NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let dataService = DataService.shared
    
    // Track sent notifications to enforce daily limit
    private var lastDailyNotificationDate: Date?
    
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
            scheduleLHReminder()
        } else {
            schedulePartnerDailyNotification()
        }
    }
    
    private func scheduleWomanDailyNotification() {
        guard let today = dataService.getTodaysCycleDay() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Moment"
        content.sound = .default
        
        switch today.fertilityLevel {
        case .peak:
            content.body = "Peak fertility today — your most fertile time"
        case .high:
            content.body = "High fertility window — good timing ahead"
        case .low:
            content.body = "Low fertility — rest and prepare"
        }
        
        // Schedule for 8 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_woman", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    private func scheduleLHReminder() {
        guard dataService.isInFertileWindow() else { return }
        guard let today = dataService.getTodaysCycleDay(), today.lhTestResult == nil else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "LH Test Reminder"
        content.body = "Don't forget to log your LH test today"
        content.sound = .default
        
        // Schedule for 7 PM
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "lh_reminder", content: content, trigger: trigger)
        
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
            content.body = tone == .explicit ? "Peak fertility today — great timing" : "Check-in time — connect with your partner"
        case .high:
            content.body = tone == .explicit ? "High fertility window" : "Good time to connect"
        case .low:
            return // No notification for low fertility
        }
        
        // Schedule for 8 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
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
        womanContent.body = "Ovulation likely within 24-36 hours"
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
            partnerContent.body = "Peak fertility detected — best timing today"
        } else {
            partnerContent.body = "Important check-in — connect with your partner"
        }
        
        let partnerRequest = UNNotificationRequest(
            identifier: "lh_positive_partner_\(Date().timeIntervalSince1970)",
            content: partnerContent,
            trigger: nil // Immediate
        )
        
        // In MVP, we send both locally. In production, partner notification goes via backend
        notificationCenter.add(womanRequest)
        notificationCenter.add(partnerRequest)
    }
    
    func sendCycleStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Cycle Started"
        content.body = "Your predictions have been updated"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "cycle_start_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Notification Content Examples
    
    /*
     EXAMPLE NOTIFICATION COPY:
     
     1. Daily Fertility (Woman - Peak):
        Title: "Moment"
        Body: "Peak fertility today — your most fertile time"
     
     2. Daily Fertility (Partner - Explicit, High):
        Title: "Moment"
        Body: "High fertility window — consider connecting today"
     
     3. Daily Fertility (Partner - Discreet, Peak):
        Title: "Moment"
        Body: "Check-in time — connect with your partner"
     
     4. LH Positive (Woman):
        Title: "LH Surge Detected"
        Body: "Ovulation likely within 24-36 hours"
     
     5. LH Positive (Partner - Explicit):
        Title: "Moment"
        Body: "Peak fertility detected — best timing today"
     
     6. LH Positive (Partner - Discreet):
        Title: "Moment"
        Body: "Important check-in — connect with your partner"
     
     7. LH Reminder:
        Title: "LH Test Reminder"
        Body: "Don't forget to log your LH test today"
     
     8. Cycle Start:
        Title: "New Cycle Started"
        Body: "Your predictions have been updated"
    */
}
