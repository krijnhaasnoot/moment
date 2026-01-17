//
//  AppleSignInService.swift
//  Moment
//
//  Handles Sign in with Apple authentication flow
//

import AuthenticationServices
import CryptoKit
import Foundation

@Observable
final class AppleSignInService: NSObject {
    static let shared = AppleSignInService()
    
    private var currentNonce: String?
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    
    private override init() {
        super.init()
    }
    
    /// Initiates Sign in with Apple flow
    func signIn() async throws -> AppleSignInResult {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    /// Generates a random nonce string for security
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    /// SHA256 hash of the nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            continuation?.resume(throwing: AppleSignInError.invalidCredentials)
            return
        }
        
        // Extract user info
        let userID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        var displayName: String?
        if let givenName = fullName?.givenName {
            displayName = givenName
            if let familyName = fullName?.familyName {
                displayName = "\(givenName) \(familyName)"
            }
        }
        
        let result = AppleSignInResult(
            identityToken: identityToken,
            nonce: nonce,
            userID: userID,
            email: email,
            fullName: displayName
        )
        
        continuation?.resume(returning: result)
        currentNonce = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                continuation?.resume(throwing: AppleSignInError.cancelled)
            case .failed:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .invalidResponse:
                continuation?.resume(throwing: AppleSignInError.invalidResponse)
            case .notHandled:
                continuation?.resume(throwing: AppleSignInError.notHandled)
            case .unknown:
                continuation?.resume(throwing: AppleSignInError.unknown)
            case .notInteractive:
                continuation?.resume(throwing: AppleSignInError.notInteractive)
            case .matchedExcludedCredential:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .credentialImport:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .credentialExport:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .preferSignInWithApple:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .deviceNotConfiguredForPasskeyCreation:
                continuation?.resume(throwing: AppleSignInError.failed)
            @unknown default:
                continuation?.resume(throwing: AppleSignInError.unknown)
            }
        } else {
            continuation?.resume(throwing: error)
        }
        currentNonce = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - Models

struct AppleSignInResult {
    let identityToken: String
    let nonce: String
    let userID: String
    let email: String?
    let fullName: String?
}

enum AppleSignInError: LocalizedError {
    case cancelled
    case failed
    case invalidResponse
    case invalidCredentials
    case notHandled
    case notInteractive
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .failed:
            return "Sign in failed"
        case .invalidResponse:
            return "Invalid response from Apple"
        case .invalidCredentials:
            return "Invalid credentials"
        case .notHandled:
            return "Request not handled"
        case .notInteractive:
            return "Not interactive"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
