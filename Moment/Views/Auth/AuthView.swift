//
//  AuthView.swift
//  Moment
//
//  Authentication screen with Apple Sign-In
//

import SwiftUI
import AuthenticationServices
import Supabase

struct AuthView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEmailAuth = false
    
    var body: some View {
        ZStack {
            Color.momentBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.momentGreen.opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.momentGreen)
                    }
                    
                    Text("Moment")
                        .font(.momentDisplay)
                        .foregroundColor(.momentCharcoal)
                    
                    Text("Timing, together")
                        .font(.momentSubheadline)
                        .foregroundColor(.momentWarmGray)
                }
                
                Spacer()
                
                // Auth buttons
                VStack(spacing: Spacing.md) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(CornerRadius.medium)
                    
                    // Google Sign In
                    Button {
                        Task {
                            await handleGoogleSignIn()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("Continue with Google")
                                .font(.momentBodyMedium)
                        }
                        .foregroundColor(.momentCharcoal)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.momentCardBackground)
                        .cornerRadius(CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.momentMist, lineWidth: 1)
                        )
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.momentMist)
                            .frame(height: 1)
                        
                        Text("or")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                            .padding(.horizontal, Spacing.sm)
                        
                        Rectangle()
                            .fill(Color.momentMist)
                            .frame(height: 1)
                    }
                    .padding(.vertical, Spacing.sm)
                    
                    // Email sign in
                    Button {
                        showingEmailAuth = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                        }
                    }
                    .buttonStyle(MomentSecondaryButtonStyle())
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.momentCaption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.sm)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
                
                // Terms & Privacy
                VStack(spacing: Spacing.xxs) {
                    Text("By continuing, you agree to our")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    HStack(spacing: Spacing.xxs) {
                        Link("Terms of Service", destination: URL(string: "https://www.kinder.so/moment/terms")!)
                            .font(.momentCaption)
                            .foregroundColor(.momentGreen)
                        
                        Text("and")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                        
                        Link("Privacy Policy", destination: URL(string: "https://www.kinder.so/moment/privacy")!)
                            .font(.momentCaption)
                            .foregroundColor(.momentGreen)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.lg)
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(viewModel: viewModel)
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Failed to get Apple ID credentials"
                return
            }
            
            // Get user info (only available on first sign in)
            let fullName = appleIDCredential.fullName
            var displayName: String?
            if let givenName = fullName?.givenName {
                displayName = givenName
                if let familyName = fullName?.familyName {
                    displayName = "\(givenName) \(familyName)"
                }
            }
            
            Task {
                await signInWithApple(
                    identityToken: identityToken,
                    fullName: displayName
                )
            }
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // User cancelled, don't show error
                return
            }
            errorMessage = error.localizedDescription
        }
    }
    
    private func signInWithApple(identityToken: String, fullName: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign in with Supabase
            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken
                )
            )
            
            // Check if profile exists
            let userId = SupabaseService.shared.client.auth.currentUser?.id
            
            if let userId = userId {
                // Try to get existing profile
                let existingProfile: Profile? = try? await SupabaseService.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                if existingProfile != nil {
                    // Existing user, go to home
                    await MainActor.run {
                        viewModel.currentScreen = .home
                        isLoading = false
                    }
                } else {
                    // New user, needs onboarding
                    // Store the name for later
                    if let name = fullName {
                        viewModel.userName = name
                    }
                    
                    await MainActor.run {
                        viewModel.onboardingStep = .selectRole
                        viewModel.currentScreen = .onboarding
                        isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func handleGoogleSignIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get Google credentials
            let (idToken, accessToken, fullName) = try await GoogleSignInService.shared.signIn()
            
            // Sign in with Supabase using Google token
            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            
            // Check if profile exists
            let userId = SupabaseService.shared.client.auth.currentUser?.id
            
            if let userId = userId {
                // Try to get existing profile
                let existingProfile: Profile? = try? await SupabaseService.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                if existingProfile != nil {
                    // Existing user, go to home
                    await MainActor.run {
                        viewModel.currentScreen = .home
                        isLoading = false
                    }
                } else {
                    // New user, needs onboarding
                    if let name = fullName {
                        viewModel.userName = name
                    }
                    
                    await MainActor.run {
                        viewModel.onboardingStep = .selectRole
                        viewModel.currentScreen = .onboarding
                        isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                // Don't show error if user cancelled
                if (error as NSError).code != -5 { // GIDSignInError.canceled
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}

// MARK: - Email Auth View

struct EmailAuthView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPasswordReset = false
    
    var isValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }
    
    /// Parse authentication errors into user-friendly messages
    private func friendlyErrorMessage(for error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        let nsError = error as NSError
        
        // Network/connectivity errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your network and try again."
            case NSURLErrorTimedOut:
                return "Connection timed out. Please try again."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return "Cannot connect to server. Please try again later."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection lost. Please try again."
            default:
                return "Network error. Please check your connection and try again."
            }
        }
        
        // Supabase/Auth specific errors
        if errorString.contains("invalid login credentials") || 
           errorString.contains("invalid_credentials") ||
           errorString.contains("invalid email or password") {
            return "Incorrect email or password. Please try again."
        }
        
        if errorString.contains("email not confirmed") {
            return "Please confirm your email address first. Check your inbox for a confirmation link."
        }
        
        if errorString.contains("user not found") || errorString.contains("no user found") {
            return "No account found with this email. Try creating an account."
        }
        
        if errorString.contains("email already registered") || errorString.contains("user already registered") {
            return "An account with this email already exists. Try signing in instead."
        }
        
        if errorString.contains("password") && errorString.contains("weak") {
            return "Password is too weak. Please use at least 6 characters."
        }
        
        if errorString.contains("too many requests") || errorString.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        }
        
        if errorString.contains("invalid email") {
            return "Please enter a valid email address."
        }
        
        // Generic fallback with the actual error for debugging
        #if DEBUG
        return "Unable to sign in: \(error.localizedDescription)"
        #else
        return "Unable to sign in. Please check your credentials and try again."
        #endif
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Toggle
                Picker("Mode", selection: $isSignUp) {
                    Text("Sign In").tag(false)
                    Text("Sign Up").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.top, Spacing.lg)
                
                // New user hint (only show on Sign In tab)
                if !isSignUp {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(.momentGreen)
                        
                        Text("New here?")
                            .font(.momentBody)
                            .fontWeight(.medium)
                            .foregroundColor(.momentCharcoal)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSignUp = true
                            }
                        } label: {
                            Text("Create an account")
                                .font(.momentBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.momentGreen)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.momentGreen)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.momentGreen.opacity(0.08))
                    )
                    .padding(.top, Spacing.sm)
                }
                
                // Form
                VStack(spacing: Spacing.md) {
                    TextField("Email", text: $email)
                        .foregroundStyle(Color.momentCharcoal)
                        .textFieldStyle(MomentTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .foregroundStyle(Color.momentCharcoal)
                        .textFieldStyle(MomentTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                    
                    if isSignUp {
                        Text("Password must be at least 6 characters")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Error
                if let error = errorMessage {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text(error)
                            .font(.momentCaption)
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.red.opacity(0.08))
                    )
                }
                
                Spacer()
                
                // Submit
                Button(isSignUp ? "Create Account" : "Sign In") {
                    Task {
                        await authenticate()
                    }
                }
                .buttonStyle(MomentPrimaryButtonStyle(isEnabled: isValid && !isLoading))
                .disabled(!isValid || isLoading)
                
                if !isSignUp {
                    Button("Forgot password?") {
                        showingPasswordReset = true
                    }
                    .buttonStyle(MomentTextButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.momentWarmGray)
                }
            }
            .momentBackground()
            .environment(\.colorScheme, .light)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetView()
            }
        }
    }
    
    private func authenticate() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            if isSignUp {
                // Sign up - will need to complete onboarding
                try await SupabaseService.shared.client.auth.signUp(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isLoading = false
                    viewModel.onboardingStep = .selectRole
                    viewModel.currentScreen = .onboarding
                    dismiss()
                }
            } else {
                // Sign in
                try await SupabaseService.shared.client.auth.signIn(
                    email: email,
                    password: password
                )
                
                // Check if profile exists
                let profile = try await SupabaseService.shared.getProfile()
                
                if profile.role == "woman" {
                    // Check if has active cycle
                    let hasActiveCycle = (try? await SupabaseService.shared.getActiveCycle()) != nil
                    await MainActor.run {
                        isLoading = false
                        viewModel.currentScreen = hasActiveCycle ? .home : .setupCycle
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        viewModel.currentScreen = .home
                        dismiss()
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = friendlyErrorMessage(for: error)
                isLoading = false
            }
        }
    }
}

// MARK: - Password Reset View

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var isValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Icon
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 50))
                    .foregroundColor(.momentGreen)
                    .padding(.top, Spacing.xl)
                
                // Instructions
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.momentBody)
                    .foregroundColor(.momentSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                
                // Email field
                TextField("Email", text: $email)
                    .foregroundStyle(Color.momentCharcoal)
                    .textFieldStyle(MomentTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, Spacing.lg)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.momentCaption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
                
                // Success message
                if let success = successMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.momentGreen)
                        Text(success)
                            .font(.momentCaption)
                            .foregroundColor(.momentGreen)
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                
                Spacer()
                
                // Submit button
                Button("Send Reset Link") {
                    Task {
                        await sendResetLink()
                    }
                }
                .buttonStyle(MomentPrimaryButtonStyle(isEnabled: isValid && !isLoading && successMessage == nil))
                .disabled(!isValid || isLoading || successMessage != nil)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.momentWarmGray)
                }
            }
            .momentBackground()
            .environment(\.colorScheme, .light)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
    
    private func sendResetLink() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(email)
            
            await MainActor.run {
                successMessage = "Reset link sent! Check your email."
                isLoading = false
            }
            
            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView(viewModel: AppViewModel())
}
