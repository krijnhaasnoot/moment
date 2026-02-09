//
//  AppDelegate.swift
//  Moment
//
//  Handles app lifecycle events and push notification registration
//

import UIKit
import UserNotifications
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.didFailToRegisterForRemoteNotifications(withError: error)
    }
    
    // MARK: - Background Fetch (for updating cycle data)
    
    nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Handle silent push notifications for data sync
        print("📬 Background notification received: \(userInfo)")
        
        // Refresh cycle data if needed
        do {
            _ = try await SupabaseService.shared.getActiveCycle()
            return .newData
        } catch {
            return .failed
        }
    }
}
