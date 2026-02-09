//
//  MomentApp.swift
//  Moment
//
//  A gentle fertility tracking app for couples trying to conceive
//

import SwiftUI
import Supabase

@main
struct MomentApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    if GoogleSignInService.shared.handleURL(url) {
                        return
                    }
                    
                    // Handle deep links for email confirmation
                    Task {
                        do {
                            try await SupabaseService.shared.client.auth.session(from: url)
                        } catch {
                            print("Error handling deep link: \(error)")
                        }
                    }
                }
        }
    }
    
    private func setupAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.momentBackground)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.momentCharcoal),
            .font: UIFont.systemFont(ofSize: 17, weight: .medium)
        ]
        navAppearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Tab bar (if used later)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.momentBackground)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
