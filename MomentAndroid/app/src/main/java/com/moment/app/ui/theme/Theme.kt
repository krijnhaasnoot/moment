package com.moment.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp

// Spacing constants matching iOS
object Spacing {
    val xxs = 4.dp
    val xs = 8.dp
    val sm = 12.dp
    val md = 16.dp
    val lg = 20.dp
    val xl = 24.dp
    val xxl = 32.dp
}

// Corner radius constants
object CornerRadius {
    val small = 8.dp
    val medium = 12.dp
    val large = 16.dp
    val xl = 20.dp
}

// Local composition for Moment colors
val LocalMomentColors = staticCompositionLocalOf { MomentColorScheme() }

// Material 3 color scheme
private val LightColorScheme = lightColorScheme(
    primary = MomentColors.Green,
    secondary = MomentColors.Teal,
    tertiary = MomentColors.Rose,
    background = MomentColors.Background,
    surface = MomentColors.CardBackground,
    onPrimary = MomentColors.CardBackground,
    onSecondary = MomentColors.CardBackground,
    onTertiary = MomentColors.Charcoal,
    onBackground = MomentColors.Charcoal,
    onSurface = MomentColors.Charcoal,
    error = MomentColors.Rose,
    onError = MomentColors.CardBackground
)

@Composable
fun MomentTheme(
    content: @Composable () -> Unit
) {
    val momentColors = MomentColorScheme()
    
    CompositionLocalProvider(LocalMomentColors provides momentColors) {
        MaterialTheme(
            colorScheme = LightColorScheme,
            typography = MomentTypography,
            content = content
        )
    }
}

// Extension to access Moment colors easily
object MomentTheme {
    val colors: MomentColorScheme
        @Composable
        get() = LocalMomentColors.current
}
