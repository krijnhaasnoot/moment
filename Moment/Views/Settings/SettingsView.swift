//
//  SettingsView.swift
//  Moment
//
//  App settings and couple management
//

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false
    
    var isWoman: Bool {
        viewModel.currentUser?.role == .woman
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Profile section
                    ProfileSection(viewModel: viewModel)
                        .padding(.horizontal, Spacing.lg)
                    
                    // Couple section
                    CoupleSection(viewModel: viewModel)
                        .padding(.horizontal, Spacing.lg)
                    
                    // Notifications section
                    NotificationSettingsSection(viewModel: viewModel, isWoman: isWoman)
                        .padding(.horizontal, Spacing.lg)
                    
                    // App info
                    AppInfoSection()
                        .padding(.horizontal, Spacing.lg)
                    
                    // Sign out button
                    Button {
                        Task {
                            await viewModel.signOut()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.momentBody)
                        .foregroundColor(.momentWarmGray)
                    }
                    .padding(.top, Spacing.lg)
                    
                    // Reset button
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        Text("Reset All Data")
                            .font(.momentBody)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .padding(.top, Spacing.sm)
                    
                    Spacer(minLength: Spacing.xxl)
                }
                .padding(.top, Spacing.lg)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.momentCharcoal)
                }
            }
            .momentBackground()
            .alert("Reset App", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.resetApp()
                        dismiss()
                    }
                }
            } message: {
                Text("This will delete all your data and start fresh. This cannot be undone.")
            }
        }
    }
}

// MARK: - Profile Section

struct ProfileSection: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var isSaving = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Profile")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.momentGreen.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(initials)
                            .font(.momentSubheadline)
                            .foregroundColor(.momentGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(viewModel.currentUser?.name ?? "")
                            .font(.momentSubheadline)
                            .foregroundColor(.momentCharcoal)
                        
                        Text(roleLabel)
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        editedName = viewModel.currentUser?.name ?? ""
                        showingEditName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.momentWarmGray)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditName) {
            EditNameSheet(
                name: $editedName,
                isSaving: $isSaving,
                onSave: {
                    await saveNameChange()
                },
                onCancel: {
                    showingEditName = false
                }
            )
            .presentationDetents([.height(280)])
        }
    }
    
    func saveNameChange() async {
        guard !editedName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSaving = true
        do {
            let update = ProfileUpdate(name: editedName.trimmingCharacters(in: .whitespaces))
            let updatedProfile = try await SupabaseService.shared.updateProfile(update)
            
            // Update local user
            await MainActor.run {
                viewModel.supabaseProfile = updatedProfile
                if var user = viewModel.currentUser {
                    user.name = updatedProfile.name
                    DataService.shared.currentUser = user
                }
                isSaving = false
                showingEditName = false
            }
        } catch {
            print("❌ Error updating name: \(error)")
            await MainActor.run {
                isSaving = false
            }
        }
    }
    
    var initials: String {
        let name = viewModel.currentUser?.name ?? ""
        let components = name.split(separator: " ")
        if let first = components.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    var roleLabel: String {
        viewModel.currentUser?.role == .woman ? "Tracking cycle" : "Partner"
    }
}

// MARK: - Edit Name Sheet

struct EditNameSheet: View {
    @Binding var name: String
    @Binding var isSaving: Bool
    let onSave: () async -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text("Edit Name")
                    .font(.momentHeadline)
                    .foregroundColor(.momentCharcoal)
                
                TextField("Your name", text: $name)
                    .textFieldStyle(MomentTextFieldStyle())
                    .foregroundStyle(Color.momentCharcoal)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                
                Button {
                    Task {
                        await onSave()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(MomentPrimaryButtonStyle(isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                
                Spacer()
            }
            .padding(Spacing.lg)
            .momentBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.momentWarmGray)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Couple Section

struct CoupleSection: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingShareSheet = false
    @State private var supabaseCouple: Couple?
    @State private var partnerName: String?
    @State private var isLoading = true
    
    var isLinked: Bool {
        supabaseCouple?.isLinked ?? viewModel.localCouple?.isLinked ?? false
    }
    
    var inviteCode: String? {
        if let code = supabaseCouple?.inviteCode {
            return code
        }
        return viewModel.partnerInviteCode.isEmpty ? nil : viewModel.partnerInviteCode
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Couple")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                VStack(spacing: Spacing.md) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: isLinked ? "link" : "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(isLinked ? .momentGreen : .momentWarmGray)
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            if isLinked {
                                Text("Connected")
                                    .font(.momentSubheadline)
                                    .foregroundColor(.momentCharcoal)
                                
                                if let name = partnerName {
                                    Text("with \(name)")
                                        .font(.momentCaption)
                                        .foregroundColor(.momentSecondaryText)
                                }
                            } else {
                                Text("Not connected")
                                    .font(.momentSubheadline)
                                    .foregroundColor(.momentCharcoal)
                                
                                Text("Invite your partner to connect")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if !isLinked, let code = supabaseCouple?.inviteCode {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Invite Code")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                
                                Text(code)
                                    .font(.momentCode)
                                    .foregroundColor(.momentCharcoal)
                            }
                            
                            Spacer()
                            
                            Button {
                                showingShareSheet = true
                            } label: {
                                Text("Share")
                                    .font(.momentCaptionMedium)
                                    .foregroundColor(.momentGreen)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(Color.momentGreen.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let code = supabaseCouple?.inviteCode {
                ShareSheet(items: [
                    "Join me on Moment! Use this code: \(code)"
                ])
            }
        }
        .task {
            await fetchCouple()
        }
    }
    
    func fetchCouple() async {
        isLoading = true
        do {
            supabaseCouple = try await SupabaseService.shared.getCouple()
            
            // If linked, fetch partner's name
            if supabaseCouple?.isLinked == true {
                partnerName = try await SupabaseService.shared.getPartnerName()
            }
            print("✅ Fetched couple from Supabase: \(supabaseCouple?.inviteCode ?? "none")")
        } catch {
            print("❌ Error fetching couple: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Notification Settings Section

struct NotificationSettingsSection: View {
    @Bindable var viewModel: AppViewModel
    let isWoman: Bool
    @State private var selectedTone: NotificationTone
    @State private var notificationsEnabled: Bool
    
    init(viewModel: AppViewModel, isWoman: Bool) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.isWoman = isWoman
        self._selectedTone = State(initialValue: viewModel.currentUser?.notificationTone ?? .discreet)
        self._notificationsEnabled = State(initialValue: viewModel.currentUser?.notificationsEnabled ?? true)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Notifications")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                VStack(spacing: Spacing.md) {
                    // Push notifications toggle
                    Toggle(isOn: $notificationsEnabled) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Push Notifications")
                                .font(.momentSubheadline)
                                .foregroundColor(.momentCharcoal)
                            
                            Text(isWoman ? "Receive daily fertility reminders" : "Receive updates from your partner")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                    }
                    .tint(.momentGreen)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        viewModel.toggleNotifications(newValue)
                    }
                    
                    // Partner notification style (woman only)
                    if isWoman && notificationsEnabled {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Partner Notification Style")
                                        .font(.momentSubheadline)
                                        .foregroundColor(.momentCharcoal)
                                    
                                    Text("How your partner receives updates")
                                        .font(.momentCaption)
                                        .foregroundColor(.momentSecondaryText)
                                }
                                
                                Spacer()
                            }
                            
                            Picker("Tone", selection: $selectedTone) {
                                ForEach(NotificationTone.allCases, id: \.self) { tone in
                                    Text(tone.displayName).tag(tone)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedTone) { _, newTone in
                                viewModel.updateNotificationTone(newTone)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            if selectedTone == .discreet {
                                NotificationPreview(
                                    title: "Moment",
                                    message: "Check-in time — connect with your partner"
                                )
                            } else {
                                NotificationPreview(
                                    title: "Moment",
                                    message: "High fertility window — consider connecting today"
                                )
                            }
                        }
                    }
                }
            }
            
            if isWoman && notificationsEnabled {
                Text("Your partner will never see your raw cycle data, symptoms, or menstruation dates.")
                    .font(.momentCaption)
                    .foregroundColor(.momentSecondaryText)
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }
}

struct NotificationPreview: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Preview")
                .font(.momentCaption)
                .foregroundColor(.momentSecondaryText)
            
            HStack(alignment: .top, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.momentGreen)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.momentCharcoal)
                        
                        Spacer()
                        
                        Text("now")
                            .font(.system(size: 12))
                            .foregroundColor(.momentSecondaryText)
                    }
                    
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.momentWarmGray)
                        .lineLimit(2)
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.momentSand.opacity(0.5))
            )
        }
    }
}

// MARK: - App Info Section

struct AppInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    InfoRow(label: "Version", value: "1.0.0")
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Moment brings clarity to one of life's most intimate moments.")
                            .font(.momentCaption)
                            .foregroundColor(.momentCharcoal)
                        Text("Designed for couples, not clinics.")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                        Text("Built by the creator of Kinder.")
                            .font(.momentCaption)
                            .foregroundColor(.momentSecondaryText)
                    }
                    
                    Divider()
                    
                    // Other apps
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("More apps")
                            .font(.momentCaptionMedium)
                            .foregroundColor(.momentSecondaryText)
                        
                        Link(destination: URL(string: "https://apps.apple.com/nl/app/birthflow/id6757489394")!) {
                            HStack(spacing: Spacing.sm) {
                                Image("BirthflowIcon")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Birthflow")
                                        .font(.momentCaptionMedium)
                                        .foregroundColor(.momentCharcoal)
                                    Text("Contraction timer")
                                        .font(.system(size: 11))
                                        .foregroundColor(.momentSecondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.momentWarmGray)
                            }
                        }
                        
                        Link(destination: URL(string: "https://apps.apple.com/nl/app/kinder-find-baby-names/id1068421785")!) {
                            HStack(spacing: Spacing.sm) {
                                Image("KinderIcon")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Kinder")
                                        .font(.momentCaptionMedium)
                                        .foregroundColor(.momentCharcoal)
                                    Text("Baby names")
                                        .font(.system(size: 11))
                                        .foregroundColor(.momentSecondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.momentWarmGray)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // WhatsApp contact
                    Link(destination: URL(string: "https://wa.me/31611220008")!) {
                        HStack(spacing: Spacing.sm) {
                            Image("WhatsappIcon")
                                .resizable()
                                .frame(width: 28, height: 28)
                            
                            Text("Contact via WhatsApp")
                                .font(.momentCaption)
                                .foregroundColor(.momentCharcoal)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.momentWarmGray)
                        }
                    }
                    
                    Divider()
                    
                    // Medical Disclaimer
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Medical Disclaimer")
                            .font(.momentCaptionMedium)
                            .foregroundColor(.momentSecondaryText)
                        
                        Text("Moment is not a medical device and does not provide medical advice. It is intended for informational purposes only and should not replace professional medical guidance.")
                            .font(.system(size: 11))
                            .foregroundColor(.momentWarmGray)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        NavigationLink(destination: LegalDisclaimerView()) {
                            Text("Read more")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.momentGreen)
                        }
                        .padding(.top, Spacing.xxs)
                    }
                }
            }
        }
    }
}

// MARK: - Legal Disclaimer View

struct LegalDisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Medical Disclaimer
                DisclaimerSection(
                    title: "Medical Disclaimer",
                    content: """
                    The information provided by Moment is for educational and informational purposes only and is not intended to be medical advice, diagnosis, or treatment.
                    
                    Moment does not provide medical, clinical, or professional healthcare services. Always seek the advice of a qualified healthcare professional regarding fertility, reproductive health, pregnancy, contraception, or any related medical condition. Never disregard or delay professional medical advice because of information provided by Moment.
                    """
                )
                
                Divider()
                
                // No Guarantee Disclaimer
                DisclaimerSection(
                    title: "No Guarantee Disclaimer",
                    content: """
                    Moment uses user-provided data, scientific research, and predictive algorithms to offer fertility insights and cycle estimates. However, accuracy cannot be guaranteed. Menstrual cycles, ovulation timing, and fertility outcomes can vary widely between individuals and from cycle to cycle.
                    
                    Moment does not guarantee conception, pregnancy prevention, or any specific health outcome.
                    """
                )
                
                Divider()
                
                // Not a Contraceptive or Diagnostic Tool
                DisclaimerSection(
                    title: "Not a Contraceptive or Diagnostic Tool",
                    content: """
                    Moment is not intended to be used as a method of contraception and should not be relied upon to prevent pregnancy. It is also not a diagnostic tool and should not be used to identify or treat medical conditions.
                    """
                )
                
                Divider()
                
                // User Responsibility
                DisclaimerSection(
                    title: "User Responsibility",
                    content: """
                    You are solely responsible for how you interpret and use the information provided by Moment. Any decisions regarding your health, fertility, or family planning are made at your own discretion and risk.
                    """
                )
                
                Divider()
                
                // Emergency Use Disclaimer
                DisclaimerSection(
                    title: "Emergency Use Disclaimer",
                    content: """
                    Moment is not intended for use in medical emergencies. If you believe you are experiencing a medical emergency, contact your healthcare provider or local emergency services immediately.
                    """
                )
                
                Divider()
                
                // Limitation of Liability
                DisclaimerSection(
                    title: "Limitation of Liability",
                    content: """
                    To the fullest extent permitted by law, Moment, its creators, and affiliates shall not be liable for any direct, indirect, incidental, consequential, or special damages arising from the use of, or inability to use, the app or its content.
                    """
                )
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Legal Disclaimer")
        .navigationBarTitleDisplayMode(.large)
        .momentBackground()
    }
}

struct DisclaimerSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.momentSubheadline)
                .foregroundColor(.momentCharcoal)
            
            Text(content)
                .font(.momentBody)
                .foregroundColor(.momentSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.momentBody)
                .foregroundColor(.momentCharcoal)
            
            Spacer()
            
            Text(value)
                .font(.momentBody)
                .foregroundColor(.momentSecondaryText)
        }
    }
}

#Preview {
    SettingsView(viewModel: AppViewModel())
}
