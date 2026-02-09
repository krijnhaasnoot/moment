package com.moment.app.ui.home

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.moment.app.data.model.FertilityLevel
import com.moment.app.data.model.SupabaseCycleDay
import com.moment.app.data.model.TemperatureUnit
import com.moment.app.data.model.UserRole
import com.moment.app.ui.calendar.CalendarScreen
import com.moment.app.ui.settings.SettingsScreen
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import kotlinx.coroutines.launch
import kotlinx.datetime.*

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(viewModel: AppViewModel) {
    val pagerState = rememberPagerState(pageCount = { 3 })
    val coroutineScope = rememberCoroutineScope()
    var showSettings by remember { mutableStateOf(false) }
    
    val isWoman = viewModel.profile?.role == "woman"
    
    Scaffold(
        containerColor = MomentTheme.colors.background,
        bottomBar = {
            NavigationBar(
                containerColor = MomentTheme.colors.cardBackground,
                tonalElevation = 0.dp
            ) {
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Today, contentDescription = "Today") },
                    label = { Text("Today") },
                    selected = pagerState.currentPage == 0,
                    onClick = { coroutineScope.launch { pagerState.animateScrollToPage(0) } },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MomentTheme.colors.primary,
                        selectedTextColor = MomentTheme.colors.primary,
                        indicatorColor = MomentTheme.colors.primary.copy(alpha = 0.1f)
                    )
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.CalendarMonth, contentDescription = "Calendar") },
                    label = { Text("Calendar") },
                    selected = pagerState.currentPage == 1,
                    onClick = { coroutineScope.launch { pagerState.animateScrollToPage(1) } },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MomentTheme.colors.primary,
                        selectedTextColor = MomentTheme.colors.primary,
                        indicatorColor = MomentTheme.colors.primary.copy(alpha = 0.1f)
                    )
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Settings, contentDescription = "Settings") },
                    label = { Text("Settings") },
                    selected = pagerState.currentPage == 2,
                    onClick = { coroutineScope.launch { pagerState.animateScrollToPage(2) } },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MomentTheme.colors.primary,
                        selectedTextColor = MomentTheme.colors.primary,
                        indicatorColor = MomentTheme.colors.primary.copy(alpha = 0.1f)
                    )
                )
            }
        }
    ) { paddingValues ->
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) { page ->
            when (page) {
                0 -> TodayScreen(viewModel)
                1 -> CalendarScreen(viewModel)
                2 -> SettingsScreen(viewModel)
            }
        }
    }
}

@Composable
fun TodayScreen(viewModel: AppViewModel) {
    val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
    val isWoman = viewModel.profile?.role == "woman"
    
    // Find today's cycle day
    val todayCycleDay = viewModel.cycleDays.find { 
        it.date == today.toString() 
    }
    
    val fertilityLevel = todayCycleDay?.fertilityLevel?.let { 
        FertilityLevel.valueOf(it.uppercase())
    } ?: FertilityLevel.LOW
    
    // Calculate day number from cycle start date
    val dayNumber = viewModel.currentCycle?.let { cycle ->
        val startDate = LocalDate.parse(cycle.startDate)
        val diff = today.toEpochDays() - startDate.toEpochDays()
        (diff + 1).toInt().coerceAtLeast(1)
    } ?: 1
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.xl)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Hello, ${viewModel.profile?.name ?: ""}",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MomentTheme.colors.textPrimary
                )
                Text(
                    text = formatTodayDate(today),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MomentTheme.colors.textSecondary
                )
            }
            
            // Partner indicator
            if (viewModel.isConnected) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MomentTheme.colors.primary.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = viewModel.partnerName?.firstOrNull()?.uppercase() ?: "P",
                            style = MaterialTheme.typography.labelMedium,
                            color = MomentTheme.colors.primary
                        )
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        // Fertility status card
        FertilityStatusCard(
            fertilityLevel = fertilityLevel,
            dayNumber = dayNumber,
            isWoman = isWoman
        )
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Quick actions
        if (isWoman) {
            WomanQuickActions(viewModel)
            
            // Temperature logging (optional, only shown if enabled)
            if (viewModel.isTemperatureTrackingEnabled) {
                Spacer(modifier = Modifier.height(Spacing.lg))
                TemperatureLoggingCard(viewModel, todayCycleDay)
            }
        } else {
            PartnerQuickActions(viewModel)
        }
        
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun FertilityStatusCard(
    fertilityLevel: FertilityLevel,
    dayNumber: Int,
    isWoman: Boolean
) {
    val (backgroundColor, statusText, description) = when (fertilityLevel) {
        FertilityLevel.LOW -> Triple(
            if (isWoman) MomentTheme.colors.fertilityLow else MomentTheme.colors.partnerLow,
            "Low fertility",
            "Outside the fertile window"
        )
        FertilityLevel.HIGH -> Triple(
            if (isWoman) MomentTheme.colors.fertilityHigh else MomentTheme.colors.partnerHigh,
            "High fertility",
            "Good timing for conception"
        )
        FertilityLevel.PEAK -> Triple(
            if (isWoman) MomentTheme.colors.fertilityPeak else MomentTheme.colors.partnerPeak,
            "Peak fertility",
            "Best timing for conception"
        )
    }
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(CornerRadius.xl),
        colors = CardDefaults.cardColors(
            containerColor = backgroundColor
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.xl),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Day $dayNumber",
                style = MaterialTheme.typography.labelLarge,
                color = MomentTheme.colors.textSecondary
            )
            
            Spacer(modifier = Modifier.height(Spacing.sm))
            
            Text(
                text = statusText,
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary
            )
            
            Spacer(modifier = Modifier.height(Spacing.xs))
            
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = MomentTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun WomanQuickActions(viewModel: AppViewModel) {
    var showLHSheet by remember { mutableStateOf(false) }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        Text(
            text = "Quick actions",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            // Log Intimacy
            QuickActionCard(
                icon = Icons.Default.Favorite,
                title = "Log Intimacy",
                onClick = { viewModel.logIntimacy() },
                modifier = Modifier.weight(1f)
            )
            
            // Log LH Test
            QuickActionCard(
                icon = Icons.Default.Science,
                title = "Log LH Test",
                onClick = { showLHSheet = true },
                modifier = Modifier.weight(1f)
            )
        }
    }
    
    if (showLHSheet) {
        LHTestSheet(
            onDismiss = { showLHSheet = false },
            onResult = { result ->
                viewModel.logLHTest(result)
                showLHSheet = false
            }
        )
    }
}

@Composable
private fun PartnerQuickActions(viewModel: AppViewModel) {
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        Text(
            text = "Quick actions",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        QuickActionCard(
            icon = Icons.Default.Favorite,
            title = "Log Intimacy",
            onClick = { viewModel.logIntimacy() },
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun QuickActionCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        onClick = onClick,
        modifier = modifier,
        shape = androidx.compose.foundation.shape.RoundedCornerShape(CornerRadius.large),
        colors = CardDefaults.cardColors(
            containerColor = MomentTheme.colors.cardBackground
        )
    ) {
        Column(
            modifier = Modifier
                .padding(Spacing.lg)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(28.dp),
                tint = MomentTheme.colors.primary
            )
            Spacer(modifier = Modifier.height(Spacing.sm))
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                color = MomentTheme.colors.textPrimary
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LHTestSheet(
    onDismiss: () -> Unit,
    onResult: (com.moment.app.data.model.LHTestResult) -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MomentTheme.colors.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Log LH Test Result",
                style = MaterialTheme.typography.headlineMedium,
                color = MomentTheme.colors.textPrimary
            )
            
            Text(
                text = "What does your test show?",
                style = MaterialTheme.typography.bodyMedium,
                color = MomentTheme.colors.textSecondary,
                modifier = Modifier.padding(top = Spacing.xs)
            )
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Negative
                Card(
                    onClick = { onResult(com.moment.app.data.model.LHTestResult.NEGATIVE) },
                    modifier = Modifier.weight(1f),
                    colors = CardDefaults.cardColors(
                        containerColor = MomentTheme.colors.divider
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .padding(Spacing.lg)
                            .fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "−",
                            style = MaterialTheme.typography.displayMedium,
                            color = MomentTheme.colors.textSecondary
                        )
                        Text(
                            text = "Negative",
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                }
                
                // Positive
                Card(
                    onClick = { onResult(com.moment.app.data.model.LHTestResult.POSITIVE) },
                    modifier = Modifier.weight(1f),
                    colors = CardDefaults.cardColors(
                        containerColor = MomentTheme.colors.fertilityPeak
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .padding(Spacing.lg)
                            .fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "+",
                            style = MaterialTheme.typography.displayMedium,
                            color = MomentTheme.colors.textPrimary
                        )
                        Text(
                            text = "Positive",
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Temperature Logging Card
// Note: Temperature tracking is optional and user-initiated.
// It is OFF by default and never sends notifications or reminders.
// Temperature data is stored but NOT currently used for fertility predictions.
// Future versions may use temperature as a secondary confirmation signal.

@Composable
private fun TemperatureLoggingCard(
    viewModel: AppViewModel,
    todayCycleDay: SupabaseCycleDay?
) {
    var temperatureInput by remember { mutableStateOf("") }
    var hasLoggedToday by remember { mutableStateOf(false) }
    var todaysTemperature by remember { mutableStateOf<Double?>(null) }
    
    val temperatureUnit = viewModel.temperatureUnit
    val placeholder = if (temperatureUnit == TemperatureUnit.CELSIUS) "36.5" else "97.7"
    
    // Load today's temperature
    LaunchedEffect(todayCycleDay) {
        val temp = todayCycleDay?.temperature
        if (temp != null) {
            todaysTemperature = temp
            hasLoggedToday = true
            val displayValue = temperatureUnit.displayValue(temp)
            temperatureInput = String.format("%.1f", displayValue)
        } else {
            hasLoggedToday = false
            todaysTemperature = null
            temperatureInput = ""
        }
    }
    
    val isValidInput = temperatureInput.replace(",", ".").toDoubleOrNull()?.let { value ->
        if (temperatureUnit == TemperatureUnit.CELSIUS) {
            value in 35.0..42.0
        } else {
            value in 95.0..108.0
        }
    } ?: false
    
    MomentCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                Icon(
                    imageVector = Icons.Default.Thermostat,
                    contentDescription = null,
                    tint = MomentTheme.colors.secondary,
                    modifier = Modifier.size(20.dp)
                )
                
                Text(
                    text = "Temperature (optional)",
                    style = MaterialTheme.typography.titleSmall,
                    color = MomentTheme.colors.textPrimary
                )
                
                Spacer(modifier = Modifier.weight(1f))
                
                if (hasLoggedToday && todaysTemperature != null) {
                    Text(
                        text = temperatureUnit.format(todaysTemperature!!),
                        style = MaterialTheme.typography.labelMedium,
                        color = MomentTheme.colors.success
                    )
                }
            }
            
            // Input row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Temperature input
                OutlinedTextField(
                    value = temperatureInput,
                    onValueChange = { temperatureInput = it },
                    placeholder = { Text(placeholder) },
                    modifier = Modifier.width(100.dp),
                    singleLine = true,
                    suffix = { Text(temperatureUnit.displayName) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MomentTheme.colors.secondary,
                        unfocusedBorderColor = MomentTheme.colors.divider
                    )
                )
                
                Spacer(modifier = Modifier.weight(1f))
                
                // Log button
                Button(
                    onClick = {
                        val value = temperatureInput.replace(",", ".").toDoubleOrNull() ?: return@Button
                        val celsius = temperatureUnit.toCelsius(value)
                        viewModel.logTemperature(celsius)
                        hasLoggedToday = true
                        todaysTemperature = celsius
                    },
                    enabled = isValidInput,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isValidInput) MomentTheme.colors.secondary else MomentTheme.colors.divider
                    )
                ) {
                    Text(if (hasLoggedToday) "Update" else "Log")
                }
            }
        }
    }
}

private fun formatTodayDate(date: LocalDate): String {
    val dayOfWeek = date.dayOfWeek.name.lowercase().replaceFirstChar { it.uppercase() }
    val month = date.month.name.lowercase().replaceFirstChar { it.uppercase() }
    return "$dayOfWeek, ${month.take(3)} ${date.dayOfMonth}"
}
