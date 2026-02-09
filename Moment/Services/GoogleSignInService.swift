//
//  GoogleSignInService.swift
//  Moment
//
//  Handles Google Sign-In authentication
//
//  SETUP: Add GoogleSignIn SDK via Swift Package Manager:
//  https://github.com/google/GoogleSignIn-iOS
//

import Foundation
import UIKit
import FirebaseCore
import GoogleSignIn

@MainActor
class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    private init() {}
    
    /// Sign in with Google
    /// Returns the ID token to use with Supabase
    func signIn() async throws -> (idToken: String, accessToken: String, fullName: String?) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw GoogleSignInError.missingClientID
        }
        
        // Create Google Sign-In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }
        
        // Perform sign-in
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingIDToken
        }
        
        let accessToken = result.user.accessToken.tokenString
        let fullName = result.user.profile?.name
        
        return (idToken, accessToken, fullName)
    }
    
    /// Sign out from Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    /// Handle URL callback (add to MomentApp.swift onOpenURL)
    func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

enum GoogleSignInError: LocalizedError {
    case missingClientID
    case noRootViewController
    case missingIDToken
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Sign-In configuration error"
        case .noRootViewController:
            return "Unable to present sign-in"
        case .missingIDToken:
            return "Failed to get authentication token"
        case .cancelled:
            return "Sign-in was cancelled"
        }
    }
}
