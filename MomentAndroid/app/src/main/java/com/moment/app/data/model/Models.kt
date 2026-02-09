package com.moment.app.data.model

import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - User Role
enum class UserRole {
    WOMAN,
    PARTNER
}

// MARK: - Notification Tone
enum class NotificationTone(val displayName: String, val description: String) {
    DISCREET("Gentle", "\"Check-in time\" — subtle reminders"),
    EXPLICIT("Direct", "\"Fertile window today\" — clear signals")
}

// MARK: - Fertility Level
enum class FertilityLevel {
    LOW,
    HIGH,
    PEAK
}

// MARK: - LH Test Result
enum class LHTestResult {
    NEGATIVE,
    POSITIVE
}

// MARK: - Temperature Unit
enum class TemperatureUnit(val displayName: String, val fullName: String) {
    CELSIUS("°C", "Celsius"),
    FAHRENHEIT("°F", "Fahrenheit");
    
    /** Convert Celsius to display value based on unit preference */
    fun displayValue(celsius: Double): Double = when (this) {
        CELSIUS -> celsius
        FAHRENHEIT -> (celsius * 9.0 / 5.0) + 32.0
    }
    
    /** Convert display value to Celsius for storage */
    fun toCelsius(value: Double): Double = when (this) {
        CELSIUS -> value
        FAHRENHEIT -> (value - 32.0) * 5.0 / 9.0
    }
    
    /** Format temperature for display */
    fun format(celsius: Double): String {
        val value = displayValue(celsius)
        return String.format("%.1f%s", value, displayName)
    }
    
    companion object {
        fun fromString(value: String): TemperatureUnit = 
            entries.find { it.name.lowercase() == value.lowercase() } ?: CELSIUS
    }
}

// MARK: - User
data class User(
    val id: String,
    val name: String,
    val role: UserRole,
    val partnerId: String? = null,
    val notificationTone: NotificationTone = NotificationTone.DISCREET,
    val notificationsEnabled: Boolean = true
)

// MARK: - Cycle
data class Cycle(
    val id: String,
    val startDate: LocalDate,
    val cycleLength: Int = 28,
    val lutealLength: Int = 14,
    val days: List<CycleDay> = emptyList(),
    val isActive: Boolean = true
) {
    val ovulationDay: Int get() = cycleLength - lutealLength
    
    val estimatedEndDate: LocalDate 
        get() = startDate.plus(DatePeriod(days = cycleLength - 1))
}

// MARK: - Cycle Day
data class CycleDay(
    val id: String,
    val date: LocalDate,
    val dayNumber: Int,
    val fertilityLevel: FertilityLevel,
    val lhTestResult: LHTestResult? = null,
    val hadIntimacy: Boolean = false,
    val notes: String? = null,
    // Temperature tracking (optional)
    // Note: Temperature is currently stored and displayed only.
    // It is NOT used to drive ovulation prediction or fertile window logic.
    // Future versions may use temperature as a secondary confirmation signal.
    val temperature: Double? = null  // Stored in Celsius
)

// MARK: - Supabase Profile
@Serializable
data class Profile(
    val id: String,
    var name: String,
    var role: String,
    @SerialName("couple_id")
    var coupleId: String? = null,
    @SerialName("notification_tone")
    var notificationTone: String = "discreet",
    @SerialName("notifications_enabled")
    var notificationsEnabled: Boolean = true,
    @SerialName("push_token")
    var pushToken: String? = null,
    @SerialName("profile_photo_url")
    var profilePhotoUrl: String? = null,
    @SerialName("average_luteal_length")
    var averageLutealLength: Int = 14,
    @SerialName("luteal_samples")
    var lutealSamples: Int = 0,
    // Temperature tracking preferences (optional feature, OFF by default)
    @SerialName("temperature_tracking_enabled")
    var temperatureTrackingEnabled: Boolean = false,
    @SerialName("temperature_info_acknowledged")
    var temperatureInfoAcknowledged: Boolean = false,
    @SerialName("temperature_unit")
    var temperatureUnit: String = "celsius",
    @SerialName("created_at")
    val createdAt: String,
    @SerialName("updated_at")
    var updatedAt: String
)

@Serializable
data class ProfileInsert(
    val id: String,
    val name: String,
    val role: String,
    @SerialName("notification_tone")
    val notificationTone: String = "discreet",
    @SerialName("notifications_enabled")
    val notificationsEnabled: Boolean = true
)

@Serializable
data class ProfileUpdate(
    val name: String? = null,
    @SerialName("notification_tone")
    val notificationTone: String? = null,
    @SerialName("notifications_enabled")
    val notificationsEnabled: Boolean? = null,
    @SerialName("push_token")
    val pushToken: String? = null,
    @SerialName("profile_photo_url")
    val profilePhotoUrl: String? = null,
    // Temperature tracking preferences
    @SerialName("temperature_tracking_enabled")
    val temperatureTrackingEnabled: Boolean? = null,
    @SerialName("temperature_info_acknowledged")
    val temperatureInfoAcknowledged: Boolean? = null,
    @SerialName("temperature_unit")
    val temperatureUnit: String? = null
)

// MARK: - Supabase Couple
@Serializable
data class Couple(
    val id: String,
    @SerialName("woman_id")
    var womanId: String? = null,
    @SerialName("partner_id")
    var partnerId: String? = null,
    @SerialName("created_by")
    val createdBy: String? = null,
    @SerialName("invite_code")
    val inviteCode: String,
    @SerialName("is_linked")
    var isLinked: Boolean = false,
    @SerialName("created_at")
    val createdAt: String,
    @SerialName("updated_at")
    var updatedAt: String
)

@Serializable
data class CoupleInsert(
    @SerialName("woman_id")
    val womanId: String? = null,
    @SerialName("partner_id")
    val partnerId: String? = null,
    @SerialName("created_by")
    val createdBy: String,
    @SerialName("invite_code")
    val inviteCode: String
)

@Serializable
data class CycleDeactivate(
    @SerialName("is_active")
    val isActive: Boolean,
    @SerialName("end_date")
    val endDate: String
)

// MARK: - Supabase Cycle
@Serializable
data class SupabaseCycle(
    val id: String,
    @SerialName("couple_id")
    val coupleId: String? = null,
    @SerialName("user_id")
    val userId: String,
    @SerialName("start_date")
    val startDate: String,
    @SerialName("end_date")
    var endDate: String? = null,
    @SerialName("cycle_length")
    var cycleLength: Int = 28,
    @SerialName("luteal_length")
    var lutealLength: Int = 14,
    @SerialName("is_active")
    var isActive: Boolean = true,
    @SerialName("created_at")
    val createdAt: String,
    @SerialName("updated_at")
    var updatedAt: String
)

@Serializable
data class CycleInsert(
    @SerialName("user_id")
    val userId: String,
    @SerialName("couple_id")
    val coupleId: String? = null,
    @SerialName("start_date")
    val startDate: String,
    @SerialName("cycle_length")
    val cycleLength: Int = 28
)

// MARK: - Supabase Cycle Day
@Serializable
data class SupabaseCycleDay(
    val id: String,
    @SerialName("cycle_id")
    val cycleId: String,
    val date: String,
    @SerialName("fertility_level")
    var fertilityLevel: String,
    @SerialName("is_menstruation")
    var isMenstruation: Boolean = false,
    @SerialName("lh_test_result")
    var lhTestResult: String? = null,
    @SerialName("had_intimacy")
    var hadIntimacy: Boolean = false,
    var notes: String? = null,
    // Temperature tracking (optional)
    var temperature: Double? = null,
    @SerialName("temperature_logged_at")
    var temperatureLoggedAt: String? = null,
    @SerialName("created_at")
    val createdAt: String,
    @SerialName("updated_at")
    var updatedAt: String
)

@Serializable
data class CycleDayInsert(
    @SerialName("cycle_id")
    val cycleId: String,
    val date: String,
    @SerialName("fertility_level")
    val fertilityLevel: String,
    @SerialName("is_menstruation")
    val isMenstruation: Boolean
)
