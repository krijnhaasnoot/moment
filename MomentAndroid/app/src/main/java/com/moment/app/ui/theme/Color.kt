package com.moment.app.ui.theme

import androidx.compose.ui.graphics.Color

// Moment Brand Colors
object MomentColors {
    // Background
    val Background = Color(0xFFFDF8F3)
    val CardBackground = Color(0xFFFFFFFF)
    
    // Text
    val Charcoal = Color(0xFF2C2C2C)
    val WarmGray = Color(0xFF8E8E93)
    val SecondaryText = Color(0xFF6B6B6B)
    
    // Neutrals
    val Mist = Color(0xFFE5E5EA)
    val Sand = Color(0xFFE8DFD5)
    
    // Accent Colors
    val Green = Color(0xFF4A7C59)
    val Teal = Color(0xFF5B8A8A)
    val Rose = Color(0xFFD4A5A5)
    val Sage = Color(0xFF9CAF88)
    
    // Fertility Colors (Woman)
    val FertilityLow = Color(0xFFE8DFD5)
    val FertilityHigh = Color(0xFFB8D4B8)
    val FertilityPeak = Color(0xFF7CB87C)
    
    // Fertility Colors (Partner view)
    val PartnerLow = Color(0xFFE5E5EA)
    val PartnerHigh = Color(0xFFB8C4D4)
    val PartnerPeak = Color(0xFF8FA4C4)
    
    // Semantic
    val Error = Color(0xFFD4A5A5)
    val Success = Color(0xFF4A7C59)
}

// Color scheme for the app
data class MomentColorScheme(
    val background: Color = MomentColors.Background,
    val cardBackground: Color = MomentColors.CardBackground,
    val primary: Color = MomentColors.Green,
    val secondary: Color = MomentColors.Teal,
    val tertiary: Color = MomentColors.Rose,
    val textPrimary: Color = MomentColors.Charcoal,
    val textSecondary: Color = MomentColors.SecondaryText,
    val textTertiary: Color = MomentColors.WarmGray,
    val divider: Color = MomentColors.Mist,
    val error: Color = MomentColors.Error,
    val success: Color = MomentColors.Success,
    // Fertility
    val fertilityLow: Color = MomentColors.FertilityLow,
    val fertilityHigh: Color = MomentColors.FertilityHigh,
    val fertilityPeak: Color = MomentColors.FertilityPeak,
    val partnerLow: Color = MomentColors.PartnerLow,
    val partnerHigh: Color = MomentColors.PartnerHigh,
    val partnerPeak: Color = MomentColors.PartnerPeak
)
