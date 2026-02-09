package com.moment.app.viewmodel

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.moment.app.data.model.*
import com.moment.app.service.SupabaseService
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.datetime.todayIn

private const val TAG = "AppViewModel"

// App navigation states
enum class AppScreen {
    LOADING,
    AUTH,
    ONBOARDING,
    SETUP_CYCLE,
    HOME
}

// Onboarding steps
enum class OnboardingStep {
    WELCOME,
    SELECT_ROLE,
    ENTER_NAME,
    PARTNER_CHOICE,
    ENTER_INVITE_CODE,
    INVITE_PARTNER,
    INVITE_MOTHER,
    SELECT_TONE
}

class AppViewModel : ViewModel() {
    
    // Map raw Supabase/network errors to friendly user messages
    private fun friendlyError(e: Exception, fallback: String): String {
        val raw = e.message ?: return fallback
        val lower = raw.lowercase()
        return when {
            "invalid login credentials" in lower -> "Incorrect email or password. Please try again."
            "email not confirmed" in lower -> "Please verify your email address first."
            "user already registered" in lower -> "An account with this email already exists. Try signing in."
            "invalid email" in lower || "unable to validate email" in lower -> "Please enter a valid email address."
            "password" in lower && ("too short" in lower || "at least" in lower) -> "Password must be at least 6 characters."
            "email rate limit" in lower || "rate limit" in lower -> "Too many attempts. Please wait a moment and try again."
            "network" in lower || "unable to resolve host" in lower || "timeout" in lower -> "No internet connection. Please check your network."
            "user not found" in lower -> "No account found with this email."
            "signup is disabled" in lower -> "Sign up is currently disabled."
            else -> fallback
        }
    }
    
    // Navigation state
    var currentScreen by mutableStateOf(AppScreen.LOADING)
        private set
    
    var onboardingStep by mutableStateOf(OnboardingStep.WELCOME)
        private set
    
    // User state
    var profile by mutableStateOf<Profile?>(null)
        private set
    
    var selectedRole by mutableStateOf(UserRole.WOMAN)
        private set
    
    var userName by mutableStateOf("")
    var inviteCode by mutableStateOf("")
    var partnerInviteCode by mutableStateOf("")
        private set
    
    var isLoadingInviteCode by mutableStateOf(false)
        private set
    
    // Cycle state
    var currentCycle by mutableStateOf<SupabaseCycle?>(null)
        private set
    
    var cycleDays by mutableStateOf<List<SupabaseCycleDay>>(emptyList())
        private set
    
    // Loading & Error states
    var isLoading by mutableStateOf(false)
        private set
    
    var errorMessage by mutableStateOf<String?>(null)
        private set
    
    fun setError(message: String?) {
        errorMessage = message
    }
    
    // Partner info
    var partnerName by mutableStateOf<String?>(null)
        private set
    
    var isConnected by mutableStateOf(false)
        private set
    
    init {
        checkAuthState()
    }
    
    // MARK: - Auth
    
    private fun checkAuthState() {
        viewModelScope.launch {
            isLoading = true
            try {
                Log.d(TAG, "checkAuthState: isAuthenticated=${SupabaseService.isAuthenticated}")
                if (SupabaseService.isAuthenticated) {
                    loadUserData()
                } else {
                    Log.d(TAG, "checkAuthState: Not authenticated, going to AUTH screen")
                    currentScreen = AppScreen.AUTH
                }
            } catch (e: Exception) {
                Log.e(TAG, "checkAuthState: Error", e)
                currentScreen = AppScreen.AUTH
            }
            isLoading = false
        }
    }
    
    private suspend fun loadUserData() {
        Log.d(TAG, "loadUserData: Fetching profile...")
        profile = SupabaseService.getProfile()
        
        if (profile == null) {
            // New user, needs onboarding
            Log.d(TAG, "loadUserData: No profile found, going to ONBOARDING")
            currentScreen = AppScreen.ONBOARDING
            onboardingStep = OnboardingStep.SELECT_ROLE
            return
        }
        
        Log.d(TAG, "loadUserData: Profile found - name=${profile?.name}, role=${profile?.role}")
        
        // Load couple info - ensure couple exists for invite code
        val couple = try {
            SupabaseService.getCouple() ?: run {
                // No couple found, create one
                Log.d(TAG, "loadUserData: No couple found, creating one...")
                SupabaseService.ensureCouple(profile?.role ?: "woman")
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadUserData: Failed to get/create couple", e)
            null
        }
        
        isConnected = couple?.isLinked == true
        partnerName = SupabaseService.getPartnerName()
        partnerInviteCode = couple?.inviteCode ?: ""
        Log.d(TAG, "loadUserData: Couple info - connected=$isConnected, inviteCode=$partnerInviteCode")
        
        // Check for active cycle
        if (profile?.role == "woman") {
            currentCycle = SupabaseService.getActiveCycle()
            if (currentCycle == null) {
                Log.d(TAG, "loadUserData: No cycle found, going to SETUP_CYCLE")
                currentScreen = AppScreen.SETUP_CYCLE
            } else {
                Log.d(TAG, "loadUserData: Cycle found, going to HOME")
                loadCycleDays()
                currentScreen = AppScreen.HOME
            }
        } else {
            // Partner
            Log.d(TAG, "loadUserData: Partner role, going to HOME")
            currentScreen = AppScreen.HOME
        }
    }
    
    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                Log.d(TAG, "signIn: Attempting sign in for $email")
                SupabaseService.signIn(email, password)
                Log.d(TAG, "signIn: Sign in successful, loading user data")
                loadUserData()
            } catch (e: Exception) {
                Log.e(TAG, "signIn: Error", e)
                errorMessage = friendlyError(e, "Unable to sign in. Please try again.")
            }
            isLoading = false
        }
    }
    
    fun signUp(email: String, password: String) {
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                SupabaseService.signUp(email, password)
                currentScreen = AppScreen.ONBOARDING
                onboardingStep = OnboardingStep.SELECT_ROLE
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to create account. Please try again.")
            }
            isLoading = false
        }
    }
    
    fun signOut() {
        viewModelScope.launch {
            try {
                SupabaseService.signOut()
                profile = null
                currentCycle = null
                cycleDays = emptyList()
                currentScreen = AppScreen.AUTH
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to sign out.")
            }
        }
    }
    
    /**
     * Load the invite code for sharing with partner.
     * This is called from Settings when the code isn't already loaded.
     */
    fun loadInviteCode() {
        if (isLoadingInviteCode) return  // Prevent duplicate calls
        
        viewModelScope.launch {
            isLoadingInviteCode = true
            try {
                Log.d(TAG, "loadInviteCode: Starting to load invite code...")
                val roleString = profile?.role ?: "woman"
                Log.d(TAG, "loadInviteCode: User role is $roleString")
                
                val couple = SupabaseService.ensureCouple(roleString)
                partnerInviteCode = couple.inviteCode
                Log.d(TAG, "loadInviteCode: Successfully loaded invite code: ${couple.inviteCode}")
            } catch (e: Exception) {
                Log.e(TAG, "loadInviteCode: Failed to load invite code", e)
            } finally {
                isLoadingInviteCode = false
            }
        }
    }
    
    fun resetPassword(email: String) {
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                SupabaseService.resetPassword(email)
                errorMessage = null
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to send reset email. Please try again.")
            }
            isLoading = false
        }
    }
    
    fun signInWithGoogle(idToken: String, accessToken: String? = null, displayName: String? = null) {
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                SupabaseService.signInWithGoogle(idToken, accessToken)
                
                // Check if new user or existing
                val existingProfile = SupabaseService.getProfile()
                if (existingProfile != null) {
                    loadUserData()
                } else {
                    // New user, store name and go to onboarding
                    displayName?.let { userName = it }
                    currentScreen = AppScreen.ONBOARDING
                    onboardingStep = OnboardingStep.SELECT_ROLE
                }
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to sign in with Google. Please try again.")
            }
            isLoading = false
        }
    }
    
    // MARK: - Onboarding
    
    fun completeWelcome() {
        onboardingStep = OnboardingStep.SELECT_ROLE
    }
    
    fun selectRole(role: UserRole) {
        selectedRole = role
        onboardingStep = OnboardingStep.ENTER_NAME
    }
    
    fun submitName() {
        if (userName.isBlank()) return
        
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                val roleString = if (selectedRole == UserRole.WOMAN) "woman" else "partner"
                profile = SupabaseService.createProfile(userName.trim(), roleString)
                
                // Ensure couple exists and get invite code
                val couple = SupabaseService.ensureCouple(roleString)
                partnerInviteCode = couple.inviteCode
                
                onboardingStep = OnboardingStep.PARTNER_CHOICE
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to create profile. Please try again.")
            }
            isLoading = false
        }
    }
    
    fun chooseJoinWithCode() {
        onboardingStep = OnboardingStep.ENTER_INVITE_CODE
    }
    
    fun chooseCreateInvite() {
        if (selectedRole == UserRole.WOMAN) {
            // Ensure invite code is available before proceeding
            if (partnerInviteCode.isBlank()) {
                viewModelScope.launch {
                    isLoading = true
                    try {
                        val couple = SupabaseService.ensureCouple("woman")
                        partnerInviteCode = couple.inviteCode
                    } catch (_: Exception) { }
                    isLoading = false
                    onboardingStep = OnboardingStep.SELECT_TONE
                }
            } else {
                onboardingStep = OnboardingStep.SELECT_TONE
            }
        } else {
            viewModelScope.launch {
                isLoading = true
                try {
                    val couple = SupabaseService.ensureCouple("partner")
                    partnerInviteCode = couple.inviteCode
                    onboardingStep = OnboardingStep.INVITE_MOTHER
                } catch (e: Exception) {
                    errorMessage = friendlyError(e, "Unable to create invite code. Please try again.")
                }
                isLoading = false
            }
        }
    }
    
    fun joinWithInviteCode() {
        if (inviteCode.length != 6) return
        
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                val roleString = if (selectedRole == UserRole.WOMAN) "woman" else "partner"
                SupabaseService.joinCouple(inviteCode, roleString)
                isConnected = true
                partnerName = SupabaseService.getPartnerName()
                
                if (selectedRole == UserRole.WOMAN) {
                    currentScreen = AppScreen.SETUP_CYCLE
                } else {
                    currentScreen = AppScreen.HOME
                }
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isLoading = false
        }
    }
    
    fun selectNotificationTone(tone: NotificationTone) {
        viewModelScope.launch {
            try {
                SupabaseService.updateProfile(
                    ProfileUpdate(notificationTone = tone.name.lowercase())
                )
                onboardingStep = OnboardingStep.INVITE_PARTNER
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }
    
    fun skipPartnerInvite() {
        currentScreen = AppScreen.SETUP_CYCLE
    }
    
    fun finishPartnerOnboarding() {
        currentScreen = AppScreen.HOME
    }
    
    fun goBackInOnboarding() {
        // Clear invite code when leaving that screen
        if (onboardingStep == OnboardingStep.ENTER_INVITE_CODE) {
            inviteCode = ""
        }
        
        onboardingStep = when (onboardingStep) {
            OnboardingStep.ENTER_NAME -> OnboardingStep.SELECT_ROLE
            OnboardingStep.PARTNER_CHOICE -> OnboardingStep.ENTER_NAME
            OnboardingStep.ENTER_INVITE_CODE -> OnboardingStep.PARTNER_CHOICE
            OnboardingStep.SELECT_TONE -> OnboardingStep.PARTNER_CHOICE
            OnboardingStep.INVITE_PARTNER -> OnboardingStep.SELECT_TONE
            OnboardingStep.INVITE_MOTHER -> OnboardingStep.PARTNER_CHOICE
            else -> onboardingStep
        }
    }
    
    // MARK: - Cycle
    
    fun createCycle(startDate: LocalDate, cycleLength: Int, lutealLength: Int = 14) {
        viewModelScope.launch {
            isLoading = true
            errorMessage = null
            try {
                currentCycle = SupabaseService.createCycle(startDate, cycleLength, lutealLength)
                loadCycleDays()
                currentScreen = AppScreen.HOME
            } catch (e: Exception) {
                errorMessage = friendlyError(e, "Unable to start cycle tracking. Please try again.")
            }
            isLoading = false
        }
    }
    
    private suspend fun loadCycleDays() {
        val cycle = currentCycle ?: return
        var days = SupabaseService.getCycleDays(cycle.id)
        
        // Auto-generate cycle days if none exist (fixes cycles created before day generation was added)
        if (days.isEmpty()) {
            try {
                SupabaseService.generateCycleDays(cycle, cycle.lutealLength)
                days = SupabaseService.getCycleDays(cycle.id)
            } catch (_: Exception) {
                // Ignore - days will just be empty
            }
        }
        
        cycleDays = days
    }
    
    fun logLHTest(result: LHTestResult) {
        val cycle = currentCycle ?: return
        val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
        
        viewModelScope.launch {
            try {
                SupabaseService.logLHTest(cycle.id, today, result.name.lowercase())
                loadCycleDays()
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }
    
    fun logIntimacy(date: LocalDate = Clock.System.todayIn(TimeZone.currentSystemDefault())) {
        val cycle = currentCycle ?: return
        
        viewModelScope.launch {
            try {
                SupabaseService.logIntimacy(cycle.id, date, true)
                loadCycleDays()
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }
    
    fun toggleIntimacy(date: LocalDate) {
        val cycle = currentCycle ?: return
        
        // Check if intimacy is already logged for this date
        val cycleDay = cycleDays.find { it.date == date.toString() }
        val currentlyHasIntimacy = cycleDay?.hadIntimacy ?: false
        
        viewModelScope.launch {
            try {
                SupabaseService.logIntimacy(cycle.id, date, !currentlyHasIntimacy)
                loadCycleDays()
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }
    
    // MARK: - Cycle Management
    
    fun startNewCycleToday() {
        viewModelScope.launch {
            try {
                Log.d(TAG, "Starting new cycle from today")
                val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
                SupabaseService.createNewCycle(today)
                currentCycle = SupabaseService.getActiveCycle()
                loadCycleDays()
                Log.d(TAG, "New cycle started successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start new cycle", e)
                errorMessage = "Failed to start new cycle: ${e.message}"
            }
        }
    }
    
    fun updateCycleStartDate(dateMillis: Long) {
        val cycle = currentCycle ?: return
        
        viewModelScope.launch {
            try {
                Log.d(TAG, "Updating cycle start date")
                // Convert millis to LocalDate
                val instant = kotlinx.datetime.Instant.fromEpochMilliseconds(dateMillis)
                val newDate = instant.toLocalDateTime(TimeZone.currentSystemDefault()).date
                
                SupabaseService.updateCycleStartDate(cycle.id, newDate)
                currentCycle = SupabaseService.getActiveCycle()
                loadCycleDays()
                Log.d(TAG, "Cycle start date updated to $newDate")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update cycle start date", e)
                errorMessage = "Failed to update cycle start date: ${e.message}"
            }
        }
    }
    
    // MARK: - Profile Editing
    
    fun updateProfileName(name: String) {
        viewModelScope.launch {
            try {
                Log.d(TAG, "Updating profile name to: $name")
                SupabaseService.updateProfile(ProfileUpdate(name = name))
                profile = SupabaseService.getProfile()
                Log.d(TAG, "Profile name updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update profile name", e)
                errorMessage = "Failed to update name: ${e.message}"
            }
        }
    }
    
    fun uploadProfilePhoto(context: Context, uri: Uri, onComplete: () -> Unit) {
        viewModelScope.launch {
            try {
                Log.d(TAG, "Uploading profile photo")
                val inputStream = context.contentResolver.openInputStream(uri)
                if (inputStream != null) {
                    val bytes = inputStream.readBytes()
                    inputStream.close()
                    
                    // Generate unique filename with timestamp to ensure uniqueness
                    val filename = "profile_${System.currentTimeMillis()}.jpg"
                    
                    val publicUrl = SupabaseService.uploadProfilePhoto(bytes, filename)
                    Log.d(TAG, "Photo uploaded to: $publicUrl")
                    
                    SupabaseService.updateProfile(ProfileUpdate(profilePhotoUrl = publicUrl))
                    Log.d(TAG, "Profile updated with new photo URL")
                    
                    // Fetch fresh profile and update state
                    val updatedProfile = SupabaseService.getProfile()
                    profile = updatedProfile
                    Log.d(TAG, "Profile photo uploaded successfully. New URL: ${updatedProfile?.profilePhotoUrl}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to upload profile photo", e)
                errorMessage = "Failed to upload photo: ${e.message}"
            } finally {
                onComplete()
            }
        }
    }
    
    // MARK: - Couple Management
    
    fun disconnectPartner(onComplete: () -> Unit) {
        viewModelScope.launch {
            try {
                Log.d(TAG, "Disconnecting from partner")
                SupabaseService.disconnectCouple()
                // Refresh data
                val couple = SupabaseService.getCouple()
                isConnected = couple?.isLinked == true
                partnerName = null
                partnerInviteCode = couple?.inviteCode ?: ""
                Log.d(TAG, "Disconnected from partner, new invite code: ${couple?.inviteCode}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to disconnect from partner", e)
                errorMessage = "Failed to disconnect: ${e.message}"
            } finally {
                onComplete()
            }
        }
    }
    
    fun refreshData() {
        viewModelScope.launch {
            try {
                profile = SupabaseService.getProfile()
                currentCycle = SupabaseService.getActiveCycle()
                loadCycleDays()
                partnerName = SupabaseService.getPartnerName()
                val couple = SupabaseService.getCouple()
                isConnected = couple?.isLinked == true
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }
    
    // MARK: - Temperature Tracking (Optional)
    // Note: Temperature tracking is an optional, user-initiated feature.
    // It is OFF by default and never sends notifications or reminders.
    // Temperature data is stored but NOT currently used for fertility predictions.
    
    val isTemperatureTrackingEnabled: Boolean
        get() = profile?.temperatureTrackingEnabled ?: false
    
    val hasAcknowledgedTemperatureInfo: Boolean
        get() = profile?.temperatureInfoAcknowledged ?: false
    
    val temperatureUnit: TemperatureUnit
        get() = TemperatureUnit.fromString(profile?.temperatureUnit ?: "celsius")
    
    fun setTemperatureTracking(enabled: Boolean) {
        viewModelScope.launch {
            try {
                SupabaseService.updateProfile(ProfileUpdate(temperatureTrackingEnabled = enabled))
                profile = SupabaseService.getProfile()
            } catch (e: Exception) {
                errorMessage = "Failed to update temperature tracking: ${e.message}"
            }
        }
    }
    
    fun acknowledgeTemperatureInfo() {
        viewModelScope.launch {
            try {
                SupabaseService.updateProfile(ProfileUpdate(temperatureInfoAcknowledged = true))
                profile = SupabaseService.getProfile()
            } catch (e: Exception) {
                errorMessage = "Failed to acknowledge temperature info: ${e.message}"
            }
        }
    }
    
    fun setTemperatureUnit(unit: TemperatureUnit) {
        viewModelScope.launch {
            try {
                SupabaseService.updateProfile(ProfileUpdate(temperatureUnit = unit.name.lowercase()))
                profile = SupabaseService.getProfile()
            } catch (e: Exception) {
                errorMessage = "Failed to update temperature unit: ${e.message}"
            }
        }
    }
    
    /** Log temperature for a given date. Temperature should be in Celsius. */
    fun logTemperature(temperatureCelsius: Double, date: LocalDate = Clock.System.todayIn(TimeZone.currentSystemDefault())) {
        val cycle = currentCycle ?: return
        
        viewModelScope.launch {
            try {
                SupabaseService.logTemperature(cycle.id, date, temperatureCelsius)
                loadCycleDays()
            } catch (e: Exception) {
                errorMessage = "Failed to log temperature: ${e.message}"
            }
        }
    }
    
    fun clearError() {
        errorMessage = null
    }
}
