//
//  OnboardingView.swift
//  Moment
//
//  Complete onboarding flow for both woman and partner
//

import SwiftUI
import Supabase

struct OnboardingView: View {
    @Bindable var viewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color.momentBackground
                .ignoresSafeArea()
            
            VStack {
                switch viewModel.onboardingStep {
                case .welcome:
                    WelcomeView(viewModel: viewModel)
                case .selectRole:
                    SelectRoleView(viewModel: viewModel)
                case .enterName:
                    EnterNameView(viewModel: viewModel)
                case .enterInviteCode:
                    EnterInviteCodeView(viewModel: viewModel)
                case .selectTone:
                    SelectToneView(viewModel: viewModel)
                case .invitePartner:
                    InvitePartnerView(viewModel: viewModel)
                }
            }
        }
        .animation(.momentSpring, value: viewModel.onboardingStep)
    }
}

// MARK: - Welcome Screen

/*
 SCREEN: Welcome
 PURPOSE: First impression - establish calm, supportive tone
 COPY EXAMPLE:
 
 Title: "Moment"
 Subtitle: "Timing, together"
 Body: "A gentle guide for couples trying to conceive. 
        No pressure. Just clarity."
 CTA: "Get Started"
*/

struct WelcomeView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo animation
            ZStack {
                Circle()
                    .fill(Color.momentGreen.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimating ? 1.1 : 1)
                
                Circle()
                    .fill(Color.momentGreen.opacity(0.25))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.momentGreen)
            }
            .padding(.bottom, Spacing.xl)
            
            Text("Moment")
                .font(.momentDisplay)
                .foregroundColor(.momentCharcoal)
            
            Text("Timing, together")
                .font(.momentSubheadline)
                .foregroundColor(.momentWarmGray)
                .padding(.top, Spacing.xs)
            
            Spacer()
            
            VStack(spacing: Spacing.md) {
                Text("A gentle guide for couples\ntrying to conceive.")
                    .font(.momentBody)
                    .foregroundColor(.momentSecondaryText)
                    .multilineTextAlignment(.center)
                
                Text("No pressure. Just clarity.")
                    .font(.momentBodyMedium)
                    .foregroundColor(.momentCharcoal)
            }
            .padding(.bottom, Spacing.xxl)
            
            Button("Get Started") {
                viewModel.completeWelcome()
            }
            .buttonStyle(MomentPrimaryButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Select Role Screen

/*
 SCREEN: Select Role
 PURPOSE: Determine user type for appropriate experience
 COPY EXAMPLE:
 
 Title: "Who's setting up?"
 Option 1: "I'm tracking my cycle" (Woman)
 Option 2: "I'm the partner" (Partner)
*/

struct SelectRoleView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showSignOutAlert = false
    
    private var currentUserEmail: String? {
        SupabaseService.shared.client.auth.currentUser?.email
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logged in indicator (tappable)
            if let email = currentUserEmail {
                Button {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.momentGreen)
                        Text("Ingelogd als \(email)")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.momentGreen.opacity(0.1))
                    )
                }
                .padding(.top, Spacing.lg)
            }
            
            Spacer()
            
            Text("Who's setting up?")
                .font(.momentDisplaySmall)
                .foregroundColor(.momentCharcoal)
                .padding(.bottom, Spacing.xxl)
            
            VStack(spacing: Spacing.md) {
                RoleOptionCard(
                    icon: "person.crop.circle",
                    title: "I'm tracking my cycle",
                    subtitle: "Log your cycle and invite your partner",
                    isSelected: false
                ) {
                    viewModel.selectRole(.woman)
                }
                
                RoleOptionCard(
                    icon: "person.2.circle",
                    title: "I'm the partner",
                    subtitle: "Join with an invite code",
                    isSelected: false
                ) {
                    viewModel.selectRole(.partner)
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            Spacer()
            Spacer()
        }
        .alert("Uitloggen?", isPresented: $showSignOutAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Uitloggen", role: .destructive) {
                Task {
                    await viewModel.signOut()
                }
            }
        } message: {
            Text("Weet je zeker dat je wilt uitloggen?")
        }
    }
}

struct RoleOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.momentGreen)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.momentSubheadline)
                        .foregroundColor(.momentCharcoal)
                    
                    Text(subtitle)
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.momentMist)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.momentCardBackground)
            )
            .momentShadow()
        }
    }
}

// MARK: - Enter Name Screen

/*
 SCREEN: Enter Name
 PURPOSE: Personalize the experience
 COPY EXAMPLE:
 
 Title: "What should we call you?"
 Placeholder: "Your name"
 Note: "This is just for your partner to see"
*/

struct EnterNameView: View {
    @Bindable var viewModel: AppViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text("What should we\ncall you?")
                .font(.momentDisplaySmall)
                .foregroundColor(.momentCharcoal)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.xs)
            
            Text("This is just for your partner to see")
                .font(.momentCaption)
                .foregroundColor(.momentSecondaryText)
                .padding(.bottom, Spacing.xl)
            
            TextField("Your name", text: $viewModel.userName)
                .textFieldStyle(MomentTextFieldStyle())
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.horizontal, Spacing.lg)
            
            Spacer()
            
            VStack(spacing: Spacing.md) {
                // Error message
                if let error = viewModel.profileError {
                    Text(error)
                        .font(.momentCaption)
                        .foregroundColor(.momentRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
                
                Button {
                    viewModel.submitName()
                } label: {
                    if viewModel.isCreatingProfile {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(MomentPrimaryButtonStyle(isEnabled: !viewModel.userName.isEmpty && !viewModel.isCreatingProfile))
                .disabled(viewModel.userName.isEmpty || viewModel.isCreatingProfile)
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Enter Invite Code Screen (Partner)

/*
 SCREEN: Enter Invite Code
 PURPOSE: Allow partner to join couple
 COPY EXAMPLE:
 
 Title: "Enter your invite code"
 Subtitle: "Ask your partner for the 6-digit code"
 Placeholder: "XXXXXX"
*/

struct EnterInviteCodeView: View {
    @Bindable var viewModel: AppViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    viewModel.goBackInOnboarding()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.momentBody)
                    }
                    .foregroundColor(.momentWarmGray)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            
            Spacer()
            
            Text("Enter your\ninvite code")
                .font(.momentDisplaySmall)
                .foregroundColor(.momentCharcoal)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.xs)
            
            Text("Ask your partner for the 6-digit code")
                .font(.momentCaption)
                .foregroundColor(.momentSecondaryText)
                .padding(.bottom, Spacing.xl)
            
            TextField("XXXXXX", text: $viewModel.inviteCode)
                .font(.momentCode)
                .foregroundStyle(Color.momentCharcoal)
                .multilineTextAlignment(.center)
                .textFieldStyle(MomentTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.horizontal, Spacing.xxl)
                .onChange(of: viewModel.inviteCode) { _, newValue in
                    viewModel.inviteCode = String(newValue.prefix(6)).uppercased()
                }
            
            Spacer()
            
            VStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your name")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                        .padding(.horizontal, Spacing.lg)
                    
                    TextField("Enter your name", text: $viewModel.userName)
                        .foregroundStyle(Color.momentCharcoal)
                        .textFieldStyle(MomentTextFieldStyle())
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .padding(.horizontal, Spacing.lg)
                }
                
                // Error message
                if let error = viewModel.joinError {
                    Text(error)
                        .font(.momentCaption)
                        .foregroundColor(.momentRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
                
                Button {
                    viewModel.joinWithInviteCode()
                } label: {
                    if viewModel.isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join")
                    }
                }
                .buttonStyle(MomentPrimaryButtonStyle(isEnabled: viewModel.inviteCode.count == 6 && !viewModel.userName.isEmpty && !viewModel.isJoining))
                .disabled(viewModel.inviteCode.count != 6 || viewModel.userName.isEmpty || viewModel.isJoining)
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Select Notification Tone Screen (Woman)

/*
 SCREEN: Select Notification Tone
 PURPOSE: Woman controls how partner receives notifications
 COPY EXAMPLE:
 
 Title: "How should we notify your partner?"
 Option 1: "Gentle" - "Check-in time" — subtle reminders
 Option 2: "Direct" - "Fertile window today" — clear signals
 Note: "You can change this anytime in settings"
*/

struct SelectToneView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTone: NotificationTone = .discreet
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text("How should we notify\nyour partner?")
                .font(.momentDisplaySmall)
                .foregroundColor(.momentCharcoal)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.xl)
            
            VStack(spacing: Spacing.md) {
                ForEach(NotificationTone.allCases, id: \.self) { tone in
                    ToneOptionCard(
                        tone: tone,
                        isSelected: selectedTone == tone
                    ) {
                        withAnimation(.momentSpring) {
                            selectedTone = tone
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            Text("You can change this anytime in settings")
                .font(.momentCaption)
                .foregroundColor(.momentSecondaryText)
                .padding(.top, Spacing.lg)
            
            Spacer()
            
            Button("Continue") {
                viewModel.selectNotificationTone(selectedTone)
            }
            .buttonStyle(MomentPrimaryButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }
}

struct ToneOptionCard: View {
    let tone: NotificationTone
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.momentGreen : Color.momentMist, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.momentGreen)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(tone.displayName)
                        .font(.momentSubheadline)
                        .foregroundColor(.momentCharcoal)
                    
                    Text(tone.description)
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                }
                
                Spacer()
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.momentCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(isSelected ? Color.momentGreen : Color.clear, lineWidth: 2)
                    )
            )
            .momentShadowSubtle()
        }
    }
}

// MARK: - Invite Partner Screen (Woman)

/*
 SCREEN: Invite Partner
 PURPOSE: Share invite code with partner
 COPY EXAMPLE:
 
 Title: "Invite your partner"
 Body: "Share this code so they can join you"
 Code: "ABC123"
 CTA: "Share Code"
 Skip: "I'll do this later"
*/

struct InvitePartnerView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text("Invite your partner")
                .font(.momentDisplaySmall)
                .foregroundColor(.momentCharcoal)
                .padding(.bottom, Spacing.xs)
            
            Text("Share this code so they can join you")
                .font(.momentBody)
                .foregroundColor(.momentSecondaryText)
                .padding(.bottom, Spacing.xl)
            
            // Invite code card
            MomentCard {
                VStack(spacing: Spacing.md) {
                    Text("Your invite code")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                    
                    Text(viewModel.partnerInviteCode)
                        .font(.momentCode)
                        .foregroundColor(.momentCharcoal)
                        .kerning(4)
                    
                    Button {
                        UIPasteboard.general.string = viewModel.partnerInviteCode
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.momentCaptionMedium)
                        .foregroundColor(.momentGreen)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            Spacer()
            
            VStack(spacing: Spacing.md) {
                Button("Share Code") {
                    showingShareSheet = true
                }
                .buttonStyle(MomentSecondaryButtonStyle())
                
                Button("Continue") {
                    viewModel.skipPartnerInvite()
                }
                .buttonStyle(MomentPrimaryButtonStyle())
                
                Text("You can always share the code later in Settings")
                    .font(.system(size: 12))
                    .foregroundColor(.momentWarmGray)
                    .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [
                "Join me on Moment! Use this code: \(viewModel.partnerInviteCode)"
            ])
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    OnboardingView(viewModel: AppViewModel())
}
