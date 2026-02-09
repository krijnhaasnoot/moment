//
//  SettingsView.swift
//  Moment
//
//  App settings and couple management
//

import SwiftUI
import PhotosUI

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
                    
                    // Cycle management section (woman only)
                    if isWoman {
                        CycleManagementSection(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Optional tracking section (woman only)
                    if isWoman {
                        OptionalTrackingSection(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                    }
                    
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    
    private var profilePhotoUrl: String? {
        viewModel.supabaseProfile?.profilePhotoUrl
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Profile")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                HStack(spacing: Spacing.md) {
                    // Profile photo with picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack {
                            if let photoUrl = profilePhotoUrl,
                               let url = URL(string: photoUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    case .failure(_):
                                        initialsView
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 50, height: 50)
                                    @unknown default:
                                        initialsView
                                    }
                                }
                            } else {
                                initialsView
                            }
                            
                            // Upload indicator
                            if isUploadingPhoto {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 50, height: 50)
                                ProgressView()
                                    .tint(.white)
                            }
                            
                            // Camera badge
                            Circle()
                                .fill(Color.momentGreen)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 18, y: 18)
                        }
                    }
                    .disabled(isUploadingPhoto)
                    
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await uploadPhoto(from: newItem)
            }
        }
        .task {
            // Refresh profile to get latest photo URL
            await viewModel.refreshProfile()
        }
    }
    
    @ViewBuilder
    var initialsView: some View {
        Circle()
            .fill(Color.momentGreen.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Text(initials)
                    .font(.momentSubheadline)
                    .foregroundColor(.momentGreen)
            )
    }
    
    func uploadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isUploadingPhoto = true
        
        do {
            // Load image data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("❌ Could not load image data")
                isUploadingPhoto = false
                return
            }
            
            // Compress and resize image
            guard let image = UIImage(data: data),
                  let compressedData = compressImage(image, maxSize: 500, quality: 0.8) else {
                print("❌ Could not process image")
                isUploadingPhoto = false
                return
            }
            
            // Upload to Supabase
            let url = try await SupabaseService.shared.uploadProfilePhoto(compressedData)
            
            await MainActor.run {
                // Update supabaseProfile with new photo URL
                if var profile = viewModel.supabaseProfile {
                    profile.profilePhotoUrl = url
                    viewModel.supabaseProfile = profile
                }
                isUploadingPhoto = false
                print("✅ Profile photo updated in UI: \(url)")
            }
        } catch {
            print("❌ Error uploading photo: \(error)")
            await MainActor.run {
                isUploadingPhoto = false
            }
        }
    }
    
    func compressImage(_ image: UIImage, maxSize: CGFloat, quality: CGFloat) -> Data? {
        var actualSize = image.size
        let ratio = maxSize / max(actualSize.width, actualSize.height)
        
        if ratio < 1 {
            actualSize = CGSize(width: actualSize.width * ratio, height: actualSize.height * ratio)
        }
        
        let renderer = UIGraphicsImageRenderer(size: actualSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: actualSize))
        }
        
        return resizedImage.jpegData(compressionQuality: quality)
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
    @State private var showingDisconnectConfirmation = false
    @State private var isDisconnecting = false
    @State private var supabaseCouple: Couple?
    @State private var partnerProfile: Profile?
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
                    HStack(spacing: Spacing.md) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 44, height: 44)
                        } else if isLinked {
                            // Partner's photo
                            partnerPhotoView
                        } else {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.momentWarmGray)
                                .frame(width: 44, height: 44)
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            if isLinked {
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text("Connected")
                                            .font(.momentSubheadline)
                                            .foregroundColor(.momentCharcoal)
                                        
                                        if let name = partnerProfile?.name {
                                            Text("with \(name)")
                                                .font(.momentCaption)
                                                .foregroundColor(.momentSecondaryText)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        showingDisconnectConfirmation = true
                                    } label: {
                                        Text("Disconnect")
                                            .font(.momentCaption)
                                            .foregroundColor(.momentWarmGray)
                                    }
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
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Share this code with your partner:")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                            
                            HStack {
                                // Large invite code display
                                Text(code)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundColor(.momentGreen)
                                    .tracking(4)
                                
                                Spacer()
                                
                                // Copy button
                                Button {
                                    UIPasteboard.general.string = code
                                    // Show brief haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(.momentGreen)
                                        .frame(width: 44, height: 44)
                                }
                                
                                // Share button
                                Button {
                                    showingShareSheet = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 18))
                                        .foregroundColor(.momentGreen)
                                        .frame(width: 44, height: 44)
                                }
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
        .alert("Disconnect Partner", isPresented: $showingDisconnectConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                Task {
                    await disconnectPartner()
                }
            }
        } message: {
            Text("This will disconnect you from your partner. You can reconnect later using a new invite code.")
        }
        .task {
            await fetchCouple()
        }
    }
    
    private func disconnectPartner() async {
        isDisconnecting = true
        defer { isDisconnecting = false }
        
        do {
            try await SupabaseService.shared.disconnectCouple()
            // Refresh couple data
            supabaseCouple = try await SupabaseService.shared.getCouple()
            partnerProfile = nil
            print("✅ Disconnected from partner")
        } catch {
            print("❌ Failed to disconnect: \(error)")
        }
    }
    
    @ViewBuilder
    var partnerPhotoView: some View {
        if let photoUrl = partnerProfile?.profilePhotoUrl,
           let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.momentGreen, lineWidth: 2)
                        )
                case .failure(_), .empty:
                    partnerInitialsView
                @unknown default:
                    partnerInitialsView
                }
            }
        } else {
            partnerInitialsView
        }
    }
    
    @ViewBuilder
    var partnerInitialsView: some View {
        Circle()
            .fill(Color.momentGreen.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(partnerInitials)
                    .font(.momentSubheadline)
                    .foregroundColor(.momentGreen)
            )
            .overlay(
                Circle()
                    .stroke(Color.momentGreen, lineWidth: 2)
            )
    }
    
    var partnerInitials: String {
        guard let name = partnerProfile?.name else { return "?" }
        let components = name.split(separator: " ")
        if let first = components.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    func fetchCouple() async {
        isLoading = true
        do {
            supabaseCouple = try await SupabaseService.shared.getCouple()
            
            // If no couple exists, create one
            if supabaseCouple == nil {
                print("📝 No couple found, creating one...")
                supabaseCouple = try await SupabaseService.shared.ensureCouple()
            }
            
            // If linked, fetch partner's profile (including photo)
            if supabaseCouple?.isLinked == true {
                partnerProfile = try await SupabaseService.shared.getPartnerProfile()
            }
            print("✅ Fetched couple from Supabase: \(supabaseCouple?.inviteCode ?? "none")")
        } catch {
            print("❌ Error fetching couple: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Cycle Management Section

struct CycleManagementSection: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    @State private var showingPeriodStartConfirmation = false
    @State private var isUpdating = false
    
    private let calendar = Calendar.current
    
    var currentCycleStart: Date? {
        viewModel.currentCycle?.startDate ?? viewModel.supabaseCycle?.startDate
    }
    
    var cycleDay: Int {
        guard let start = currentCycleStart else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: Date()).day ?? 0
        return days + 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Cycle")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                VStack(spacing: Spacing.md) {
                    // Current cycle info
                    if let startDate = currentCycleStart {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Current cycle")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                
                                Text("Day \(cycleDay)")
                                    .font(.momentHeadline)
                                    .foregroundColor(.momentCharcoal)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                                Text("Started")
                                    .font(.momentCaption)
                                    .foregroundColor(.momentSecondaryText)
                                
                                Text(startDate, style: .date)
                                    .font(.momentBody)
                                    .foregroundColor(.momentCharcoal)
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Change cycle start date
                    Button {
                        selectedDate = currentCycleStart ?? Date()
                        showingDatePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 18))
                                .foregroundColor(.momentTeal)
                            
                            Text("Change cycle start date")
                                .font(.momentBody)
                                .foregroundColor(.momentCharcoal)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.momentSecondaryText)
                        }
                    }
                    
                    Divider()
                    
                    // Period starts now button
                    Button {
                        showingPeriodStartConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.momentRose)
                            
                            Text("My period started today")
                                .font(.momentBody)
                                .foregroundColor(.momentCharcoal)
                            
                            Spacer()
                            
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isUpdating)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                title: "When did your last period start?",
                selectedDate: $selectedDate,
                onSave: {
                    Task {
                        await updateCycleStartDate(to: selectedDate)
                    }
                }
            )
        }
        .alert("Start New Cycle", isPresented: $showingPeriodStartConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, start new cycle") {
                Task {
                    await startNewCycle()
                }
            }
        } message: {
            Text("This will end your current cycle and start a new one from today. Your previous cycle data will be saved.")
        }
    }
    
    private func updateCycleStartDate(to newDate: Date) async {
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            try await viewModel.updateCycleStartDate(to: newDate)
            print("✅ Cycle start date updated to \(newDate)")
        } catch {
            print("❌ Failed to update cycle start date: \(error)")
        }
    }
    
    private func startNewCycle() async {
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            try await viewModel.startNewCycle()
            print("✅ New cycle started")
        } catch {
            print("❌ Failed to start new cycle: \(error)")
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let title: String
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text(title)
                    .font(.momentSubheadline)
                    .foregroundColor(.momentCharcoal)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.lg)
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Spacing.md)
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.momentWarmGray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.momentGreen)
                }
            }
            .momentBackground()
        }
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

// MARK: - Optional Tracking Section

struct OptionalTrackingSection: View {
    @Bindable var viewModel: AppViewModel
    @State private var temperatureEnabled: Bool = false
    @State private var showingTemperatureInfo: Bool = false
    @State private var selectedUnit: TemperatureUnit = .celsius
    
    init(viewModel: AppViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Optional tracking")
                .font(.momentCaptionMedium)
                .foregroundColor(.momentSecondaryText)
            
            MomentCard {
                VStack(spacing: Spacing.md) {
                    // Temperature tracking toggle
                    Toggle(isOn: $temperatureEnabled) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Track basal body temperature")
                                .font(.momentSubheadline)
                                .foregroundColor(.momentCharcoal)
                            
                            Text("Optional. Only enable this if you already track temperature and feel comfortable doing so.")
                                .font(.momentCaption)
                                .foregroundColor(.momentSecondaryText)
                        }
                    }
                    .tint(.momentGreen)
                    .onChange(of: temperatureEnabled) { _, newValue in
                        if newValue {
                            // Check if user has seen the info screen
                            if !viewModel.hasAcknowledgedTemperatureInfo {
                                showingTemperatureInfo = true
                            } else {
                                viewModel.setTemperatureTracking(enabled: true)
                            }
                        } else {
                            viewModel.setTemperatureTracking(enabled: false)
                        }
                    }
                    
                    // Temperature unit picker (only shown when enabled)
                    if temperatureEnabled {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Temperature unit")
                                    .font(.momentSubheadline)
                                    .foregroundColor(.momentCharcoal)
                            }
                            
                            Spacer()
                            
                            Picker("Unit", selection: $selectedUnit) {
                                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                                    Text(unit.fullName).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .onChange(of: selectedUnit) { _, newUnit in
                                viewModel.setTemperatureUnit(newUnit)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            temperatureEnabled = viewModel.isTemperatureTrackingEnabled
            selectedUnit = viewModel.temperatureUnit
        }
        .sheet(isPresented: $showingTemperatureInfo, onDismiss: {
            // If user dismissed without acknowledging, revert toggle
            if !viewModel.hasAcknowledgedTemperatureInfo {
                temperatureEnabled = false
            }
        }) {
            TemperatureInfoSheet(
                onAcknowledge: {
                    viewModel.acknowledgeTemperatureInfo()
                    viewModel.setTemperatureTracking(enabled: true)
                    showingTemperatureInfo = false
                },
                onDismiss: {
                    temperatureEnabled = false
                    showingTemperatureInfo = false
                }
            )
        }
    }
}

// MARK: - Temperature Info Sheet

struct TemperatureInfoSheet: View {
    let onAcknowledge: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Title
                    Text("About temperature tracking")
                        .font(.momentHeadline)
                        .foregroundColor(.momentCharcoal)
                        .padding(.top, Spacing.lg)
                    
                    // Body text
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Some people choose to track basal body temperature to better understand their cycle.")
                            .font(.momentBody)
                            .foregroundColor(.momentCharcoal)
                        
                        Text("This is optional and requires daily consistency. Moment will never require temperature input and will not remind you to log it.")
                            .font(.momentBody)
                            .foregroundColor(.momentCharcoal)
                        
                        Text("Logged temperatures are used only as an additional signal to refine timing insights over time.")
                            .font(.momentBody)
                            .foregroundColor(.momentCharcoal)
                    }
                    
                    Spacer(minLength: Spacing.xxl)
                    
                    // Footer
                    Text("Moment is not a medical device.")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Button
                    Button {
                        onAcknowledge()
                    } label: {
                        Text("Got it")
                            .font(.momentBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.momentGreen)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .momentBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.momentWarmGray)
                    }
                }
            }
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
