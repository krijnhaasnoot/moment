//
//  PushNotificationService.swift
//  Moment
//
//  Handles push notification registration and delivery
//

import Foundation
import UserNotifications
import UIKit

@Observable
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    var isRegistered = false
    var pushToken: String?
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
    }
    
    // MARK: - Permission & Registration
    
    /// Request notification permissions and register for remote notifications
    func requestPermissionAndRegister() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            // Update status
            let settings = await center.notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
            }
            
            return granted
        } catch {
            print("❌ Push notification permission error: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
        return settings.authorizationStatus
    }
    
    // MARK: - Token Management
    
    /// Called when APNs registration succeeds
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.pushToken = token
        self.isRegistered = true
        
        print("✅ Push token: \(token)")
        
        // Save token to Supabase
        Task {
            do {
                try await SupabaseService.shared.updatePushToken(token)
                print("✅ Push token saved to Supabase")
            } catch {
                print("❌ Failed to save push token: \(error)")
            }
        }
    }
    
    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("❌ Failed to register for push notifications: \(error)")
        self.isRegistered = false
    }
    
    // MARK: - Notification Handling
    
    /// Handle notification received while app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        print("📬 Foreground notification: \(userInfo)")
        
        // Show banner and play sound even when app is open
        return [.banner, .sound, .badge]
    }
    
    /// Handle notification tap
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        // Handle different notification types
        if let type = userInfo["type"] as? String {
            handleNotificationType(type, userInfo: userInfo)
        }
    }
    
    private func handleNotificationType(_ type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "lh_positive":
            // Navigate to today view
            NotificationCenter.default.post(name: .navigateToToday, object: nil)
            
        case "daily_fertility":
            // Navigate to today view
            NotificationCenter.default.post(name: .navigateToToday, object: nil)
            
        case "lh_reminder":
            // Legacy: LH reminders are no longer scheduled, but handle old notifications gracefully
            NotificationCenter.default.post(name: .openLHLogging, object: nil)
            
        default:
            break
        }
    }
    
    // MARK: - Local Notifications (Fallback)
    
    /// Schedule a local notification (for testing or offline)
    func scheduleLocalNotification(
        title: String,
        body: String,
        delay: TimeInterval = 5,
        identifier: String = UUID().uuidString
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule local notification: \(error)")
            } else {
                print("✅ Local notification scheduled")
            }
        }
    }
    
    /// Schedule daily LH reminder during fertile window
    func scheduleLHReminder(at hour: Int = 19, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "LH Test Reminder"
        content.body = "Don't forget to log your LH test today"
        content.sound = .default
        content.userInfo = ["type": "lh_reminder"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "lh_reminder_daily", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Cancel all scheduled local notifications
    func cancelAllLocalNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Cancel specific notification
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToToday = Notification.Name("navigateToToday")
    static let openLHLogging = Notification.Name("openLHLogging")
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return handleForegroundNotification(notification)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handleNotificationResponse(response)
    }
}
