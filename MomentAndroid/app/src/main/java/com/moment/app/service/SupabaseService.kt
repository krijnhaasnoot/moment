package com.moment.app.service

import android.content.Context
import android.util.Log
import com.moment.app.BuildConfig
import com.moment.app.data.model.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.Google
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.providers.builtin.IDToken
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.serializer.KotlinXSerializer
import kotlin.time.Duration.Companion.seconds
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.datetime.Clock
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.plus
import kotlinx.datetime.todayIn

object SupabaseService {
    
    private const val TAG = "SupabaseService"
    
    private lateinit var client: SupabaseClient
    private lateinit var appContext: Context
    
    fun initialize(context: Context) {
        appContext = context.applicationContext
        
        // Custom JSON configuration for backward compatibility
        // Ignores unknown keys (for future fields) and allows missing keys with defaults
        val json = Json {
            ignoreUnknownKeys = true
            isLenient = true
            coerceInputValues = true
        }
        
        client = createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            defaultSerializer = KotlinXSerializer(json)
            install(Auth)
            install(Postgrest)
            install(Storage)
        }
    }
    
    // MARK: - Auth
    
    val currentUserId: String?
        get() = client.auth.currentUserOrNull()?.id
    
    val isAuthenticated: Boolean
        get() = client.auth.currentUserOrNull() != null
    
    suspend fun signUp(email: String, password: String) {
        client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
    }
    
    suspend fun signIn(email: String, password: String) {
        client.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }
    
    suspend fun signOut() {
        client.auth.signOut()
    }
    
    suspend fun resetPassword(email: String) {
        client.auth.resetPasswordForEmail(email)
    }
    
    suspend fun signInWithGoogle(idToken: String, accessToken: String? = null) {
        client.auth.signInWith(IDToken) {
            this.provider = Google
            this.idToken = idToken
            accessToken?.let { this.accessToken = it }
        }
    }
    
    // MARK: - Profile
    
    suspend fun getProfile(): Profile? {
        val userId = currentUserId ?: run {
            Log.d("SupabaseService", "getProfile: No current user ID")
            return null
        }
        
        return try {
            val profile = client.postgrest
                .from("profiles")
                .select {
                    filter {
                        eq("id", userId)
                    }
                }
                .decodeSingleOrNull<Profile>()
            
            if (profile != null) {
                Log.d("SupabaseService", "getProfile: Found profile for user $userId")
            } else {
                Log.d("SupabaseService", "getProfile: No profile found for user $userId")
            }
            profile
        } catch (e: Exception) {
            Log.e("SupabaseService", "getProfile: Error fetching profile: ${e.message}", e)
            null
        }
    }
    
    suspend fun createProfile(name: String, role: String): Profile {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        
        val insert = ProfileInsert(
            id = userId,
            name = name,
            role = role
        )
        
        client.postgrest
            .from("profiles")
            .insert(insert)
        
        return getProfile() ?: throw Exception("Failed to create profile")
    }
    
    suspend fun updateProfile(update: ProfileUpdate): Profile {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        
        client.postgrest
            .from("profiles")
            .update(update) {
                filter {
                    eq("id", userId)
                }
            }
        
        return getProfile() ?: throw Exception("Failed to update profile")
    }
    
    suspend fun uploadProfilePhoto(imageBytes: ByteArray, filename: String): String {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        
        Log.d(TAG, "Uploading profile photo: $filename for user: $userId")
        
        // Upload to storage bucket - use consistent path
        val path = "$userId/$filename"
        
        try {
            client.storage
                .from("profile-photos")
                .upload(path, imageBytes, upsert = true)
            Log.d(TAG, "Upload successful to path: $path")
        } catch (e: Exception) {
            Log.e(TAG, "Upload failed, trying with upsert", e)
            // Try delete first then upload
            try {
                client.storage.from("profile-photos").delete(path)
            } catch (deleteError: Exception) {
                Log.d(TAG, "Delete failed (file may not exist): ${deleteError.message}")
            }
            client.storage
                .from("profile-photos")
                .upload(path, imageBytes)
        }
        
        // Get signed URL (valid for 1 year) - more secure than public URL
        val signedUrlPath = client.storage
            .from("profile-photos")
            .createSignedUrl(path, expiresIn = 31536000.seconds)
        
        // Construct full URL
        val fullUrl = "${BuildConfig.SUPABASE_URL}/storage/v1/$signedUrlPath"
        
        Log.d(TAG, "Profile photo uploaded, signed URL: $fullUrl")
        return fullUrl
    }
    
    // MARK: - Couple
    
    suspend fun getCouple(): Couple? {
        val userId = currentUserId ?: run {
            Log.d("SupabaseService", "getCouple: No user ID")
            return null
        }
        
        Log.d("SupabaseService", "getCouple: Looking for couple for user $userId")
        
        // First, check if profile has a couple_id
        val profile = getProfile()
        if (profile?.coupleId != null) {
            Log.d("SupabaseService", "getCouple: Profile has couple_id ${profile.coupleId}")
            try {
                val couple = client.postgrest
                    .from("couples")
                    .select {
                        filter {
                            eq("id", profile.coupleId!!)
                        }
                    }
                    .decodeSingleOrNull<Couple>()
                
                if (couple != null) {
                    Log.d("SupabaseService", "getCouple: Found couple via profile.couple_id: ${couple.inviteCode}")
                    return couple
                }
            } catch (e: Exception) {
                Log.e("SupabaseService", "getCouple: Error fetching by couple_id", e)
            }
        }
        
        // Fallback: Try to find as woman
        var couple = try {
            client.postgrest
                .from("couples")
                .select {
                    filter {
                        eq("woman_id", userId)
                    }
                }
                .decodeSingleOrNull<Couple>()
        } catch (e: Exception) {
            Log.e("SupabaseService", "getCouple: Error finding as woman", e)
            null
        }
        
        if (couple != null) {
            Log.d("SupabaseService", "getCouple: Found couple as woman: ${couple.inviteCode}")
            return couple
        }
        
        // Try to find as partner
        couple = try {
            client.postgrest
                .from("couples")
                .select {
                    filter {
                        eq("partner_id", userId)
                    }
                }
                .decodeSingleOrNull<Couple>()
        } catch (e: Exception) {
            Log.e("SupabaseService", "getCouple: Error finding as partner", e)
            null
        }
        
        if (couple != null) {
            Log.d("SupabaseService", "getCouple: Found couple as partner: ${couple.inviteCode}")
        } else {
            Log.d("SupabaseService", "getCouple: No couple found for user $userId")
        }
        
        return couple
    }
    
    suspend fun getInviteCode(): String? {
        return getCouple()?.inviteCode
    }
    
    /**
     * Ensure a couple exists for the current user. If the DB trigger didn't
     * create one (or the user is a partner), create it from the app side.
     * Returns the existing or newly created couple.
     */
    suspend fun ensureCouple(role: String): Couple {
        Log.d("SupabaseService", "ensureCouple: Checking for existing couple, role=$role")
        
        // Check if couple already exists
        getCouple()?.let { 
            Log.d("SupabaseService", "ensureCouple: Found existing couple with code ${it.inviteCode}")
            return it 
        }
        
        val userId = currentUserId ?: throw Exception("Not authenticated")
        Log.d("SupabaseService", "ensureCouple: No couple found, creating new one for user $userId")
        
        // Generate a 6-char invite code (same charset as DB function)
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        val inviteCode = (1..6).map { chars.random() }.joinToString("")
        Log.d("SupabaseService", "ensureCouple: Generated invite code $inviteCode")
        
        val insert = if (role == "woman") {
            CoupleInsert(womanId = userId, createdBy = userId, inviteCode = inviteCode)
        } else {
            CoupleInsert(partnerId = userId, createdBy = userId, inviteCode = inviteCode)
        }
        
        try {
            client.postgrest
                .from("couples")
                .insert(insert)
            Log.d("SupabaseService", "ensureCouple: Inserted couple record")
        } catch (e: Exception) {
            Log.e("SupabaseService", "ensureCouple: Failed to insert couple", e)
            throw e
        }
        
        // Update profile with couple_id
        val couple = getCouple() ?: throw Exception("Failed to create couple")
        Log.d("SupabaseService", "ensureCouple: Got couple ID ${couple.id}, updating profile")
        
        try {
            client.postgrest
                .from("profiles")
                .update(mapOf("couple_id" to couple.id)) {
                    filter {
                        eq("id", userId)
                    }
                }
            Log.d("SupabaseService", "ensureCouple: Updated profile with couple_id")
        } catch (e: Exception) {
            Log.e("SupabaseService", "ensureCouple: Failed to update profile", e)
            // Don't throw - the couple was created successfully
        }
        
        return couple
    }
    
    suspend fun joinCouple(inviteCode: String, role: String): Couple {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        
        // Find couple by invite code
        val couple = client.postgrest
            .from("couples")
            .select {
                filter {
                    eq("invite_code", inviteCode.uppercase())
                }
            }
            .decodeSingleOrNull<Couple>() ?: throw Exception("Invalid invite code")
        
        // Determine which field to update based on role
        val updateField = if (role == "woman") "woman_id" else "partner_id"
        
        // Check if slot is available
        if (role == "woman" && couple.womanId != null && couple.isLinked) {
            throw Exception("This couple already has a woman linked")
        }
        if (role == "partner" && couple.partnerId != null && couple.isLinked) {
            throw Exception("This couple already has a partner linked")
        }
        
        // Update the couple
        client.postgrest
            .from("couples")
            .update(mapOf(
                updateField to userId,
                "is_linked" to true
            )) {
                filter {
                    eq("id", couple.id)
                }
            }
        
        // Update profile with couple_id
        client.postgrest
            .from("profiles")
            .update(mapOf("couple_id" to couple.id)) {
                filter {
                    eq("id", userId)
                }
            }
        
        return getCouple() ?: throw Exception("Failed to join couple")
    }
    
    /**
     * Disconnect from partner - removes the partner link but keeps the couple record.
     * A new invite code is generated for future connections.
     */
    suspend fun disconnectCouple() {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        val couple = getCouple() ?: throw Exception("No couple found")
        
        Log.d(TAG, "Disconnecting couple: ${couple.id}")
        
        val isWoman = couple.womanId == userId
        
        // Generate a new invite code
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        val newInviteCode = (1..6).map { chars.random() }.joinToString("")
        
        // Keep the current user, remove the other partner
        @Serializable
        data class CoupleDisconnect(
            @SerialName("woman_id") val womanId: String?,
            @SerialName("partner_id") val partnerId: String?,
            @SerialName("invite_code") val inviteCode: String,
            @SerialName("is_linked") val isLinked: Boolean
        )
        
        val update = CoupleDisconnect(
            womanId = if (isWoman) userId else null,
            partnerId = if (!isWoman) userId else null,
            inviteCode = newInviteCode,
            isLinked = false
        )
        
        client.postgrest
            .from("couples")
            .update(update) {
                filter {
                    eq("id", couple.id)
                }
            }
        
        Log.d(TAG, "Disconnected from partner, new invite code: $newInviteCode")
    }
    
    suspend fun getPartnerName(): String? {
        val couple = getCouple() ?: return null
        if (!couple.isLinked) return null
        
        val userId = currentUserId ?: return null
        val partnerId = if (userId == couple.womanId) couple.partnerId else couple.womanId
        partnerId ?: return null
        
        val profile = client.postgrest
            .from("profiles")
            .select(columns = Columns.list("name")) {
                filter {
                    eq("id", partnerId)
                }
            }
            .decodeSingleOrNull<Profile>()
        
        return profile?.name
    }
    
    // MARK: - Cycle
    
    suspend fun getActiveCycle(): SupabaseCycle? {
        val userId = currentUserId ?: return null
        
        return client.postgrest
            .from("cycles")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("is_active", true)
                }
            }
            .decodeSingleOrNull<SupabaseCycle>()
    }
    
    suspend fun createCycle(startDate: LocalDate, cycleLength: Int, lutealLength: Int): SupabaseCycle {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        val profile = getProfile() ?: throw Exception("Profile not found")
        
        // Deactivate previous cycles
        client.postgrest
            .from("cycles")
            .update(CycleDeactivate(
                isActive = false,
                endDate = Clock.System.todayIn(TimeZone.currentSystemDefault()).toString()
            )) {
                filter {
                    eq("user_id", userId)
                    eq("is_active", true)
                }
            }
        
        val insert = CycleInsert(
            userId = userId,
            coupleId = profile.coupleId,
            startDate = startDate.toString(),
            cycleLength = cycleLength
        )
        
        client.postgrest
            .from("cycles")
            .insert(insert)
        
        val cycle = getActiveCycle() ?: throw Exception("Failed to create cycle")
        
        // Generate cycle days with fertility levels
        generateCycleDays(cycle, lutealLength)
        
        return cycle
    }
    
    /**
     * Create a new cycle with today's date, deactivating any existing cycle.
     * Uses the user's learned luteal length for fertility predictions.
     */
    suspend fun createNewCycle(startDate: LocalDate): SupabaseCycle {
        val profile = getProfile() ?: throw Exception("Profile not found")
        val cycleLength = 28 // Default cycle length
        val lutealLength = profile.averageLutealLength
        
        Log.d(TAG, "Creating new cycle: startDate=$startDate, cycleLength=$cycleLength, lutealLength=$lutealLength")
        
        return createCycle(startDate, cycleLength, lutealLength)
    }
    
    /**
     * Update the start date of an existing cycle.
     * This will regenerate all cycle days with new dates.
     */
    suspend fun updateCycleStartDate(cycleId: String, newStartDate: LocalDate) {
        Log.d(TAG, "Updating cycle $cycleId start date to $newStartDate")
        
        // Get current cycle info
        val cycle = client.postgrest
            .from("cycles")
            .select {
                filter {
                    eq("id", cycleId)
                }
            }
            .decodeSingle<SupabaseCycle>()
        
        // Delete existing cycle days
        client.postgrest
            .from("cycle_days")
            .delete {
                filter {
                    eq("cycle_id", cycleId)
                }
            }
        
        // Update cycle start date
        @Serializable
        data class CycleStartDateUpdate(
            @SerialName("start_date") val startDate: String
        )
        
        client.postgrest
            .from("cycles")
            .update(CycleStartDateUpdate(startDate = newStartDate.toString())) {
                filter {
                    eq("id", cycleId)
                }
            }
        
        // Regenerate cycle days with new start date
        val updatedCycle = SupabaseCycle(
            id = cycle.id,
            userId = cycle.userId,
            coupleId = cycle.coupleId,
            startDate = newStartDate.toString(),
            endDate = cycle.endDate,
            cycleLength = cycle.cycleLength,
            isActive = cycle.isActive,
            createdAt = cycle.createdAt,
            updatedAt = Clock.System.now().toString()
        )
        
        // Get user's personalized luteal length
        val profile = getProfile()
        val lutealLength = profile?.averageLutealLength ?: 14
        
        generateCycleDays(updatedCycle, lutealLength)
        
        Log.d(TAG, "Cycle start date updated and days regenerated")
    }
    
    /**
     * Generate cycle days with calculated fertility levels.
     * Mirrors iOS generateCycleDays logic.
     */
    suspend fun generateCycleDays(cycle: SupabaseCycle, lutealLength: Int = 14) {
        val cycleLength = maxOf(1, cycle.cycleLength)
        val startDate = LocalDate.parse(cycle.startDate)
        
        // Calculate ovulation day using luteal phase length
        val safeLutealLength = lutealLength.coerceIn(8, 18)
        val ovulationDay = maxOf(1, cycleLength - safeLutealLength)
        val fertileStart = maxOf(1, ovulationDay - 5)
        val fertileEnd = minOf(cycleLength, ovulationDay + 1)
        
        val days = (0 until cycleLength).map { dayOffset ->
            val date = startDate.plus(DatePeriod(days = dayOffset))
            val dayNumber = dayOffset + 1
            val isMenstruation = dayNumber <= 5
            
            val fertilityLevel = when {
                dayNumber == ovulationDay || dayNumber == ovulationDay - 1 -> "peak"
                dayNumber in fertileStart..fertileEnd -> "high"
                else -> "low"
            }
            
            CycleDayInsert(
                cycleId = cycle.id,
                date = date.toString(),
                fertilityLevel = fertilityLevel,
                isMenstruation = isMenstruation
            )
        }
        
        client.postgrest
            .from("cycle_days")
            .insert(days)
    }
    
    suspend fun getCycleDays(cycleId: String): List<SupabaseCycleDay> {
        return client.postgrest
            .from("cycle_days")
            .select {
                filter {
                    eq("cycle_id", cycleId)
                }
            }
            .decodeList<SupabaseCycleDay>()
    }
    
    suspend fun logLHTest(cycleId: String, date: LocalDate, result: String) {
        client.postgrest
            .from("cycle_days")
            .update(mapOf("lh_test_result" to result)) {
                filter {
                    eq("cycle_id", cycleId)
                    eq("date", date.toString())
                }
            }
    }
    
    suspend fun logIntimacy(cycleId: String, date: LocalDate, hadIntimacy: Boolean) {
        client.postgrest
            .from("cycle_days")
            .update(mapOf("had_intimacy" to hadIntimacy)) {
                filter {
                    eq("cycle_id", cycleId)
                    eq("date", date.toString())
                }
            }
    }
    
    // MARK: - Temperature Tracking (Optional)
    // Note: Temperature is stored but NOT currently used for fertility predictions.
    // Future versions may use temperature as a secondary confirmation signal.
    
    suspend fun logTemperature(cycleId: String, date: LocalDate, temperatureCelsius: Double) {
        val now = kotlinx.datetime.Clock.System.now().toString()
        
        client.postgrest
            .from("cycle_days")
            .update(mapOf(
                "temperature" to temperatureCelsius,
                "temperature_logged_at" to now
            )) {
                filter {
                    eq("cycle_id", cycleId)
                    eq("date", date.toString())
                }
            }
    }
    
    suspend fun clearTemperature(cycleId: String, date: LocalDate) {
        client.postgrest
            .from("cycle_days")
            .update(mapOf(
                "temperature" to null,
                "temperature_logged_at" to null
            )) {
                filter {
                    eq("cycle_id", cycleId)
                    eq("date", date.toString())
                }
            }
    }
    
    // MARK: - Profile Photo
    
    suspend fun deleteProfilePhoto() {
        val userId = currentUserId ?: throw Exception("Not authenticated")
        val filePath = "${userId.lowercase()}/profile.jpg"
        
        client.storage
            .from("profile-photos")
            .delete(filePath)
        
        updateProfile(ProfileUpdate(profilePhotoUrl = null))
    }
    
    // MARK: - Partner Cycle (for partners viewing woman's cycle)
    
    suspend fun getPartnerCycle(): SupabaseCycle? {
        val couple = getCouple() ?: return null
        if (!couple.isLinked) return null
        
        val userId = currentUserId ?: return null
        val womanId = if (userId == couple.partnerId) couple.womanId else return null
        womanId ?: return null
        
        return client.postgrest
            .from("cycles")
            .select {
                filter {
                    eq("user_id", womanId)
                    eq("is_active", true)
                }
            }
            .decodeSingleOrNull<SupabaseCycle>()
    }
}
