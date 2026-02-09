package com.moment.app.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.moment.app.data.model.FertilityLevel
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import kotlinx.datetime.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(viewModel: AppViewModel) {
    var currentMonth by remember { 
        mutableStateOf(Clock.System.todayIn(TimeZone.currentSystemDefault()).let { 
            YearMonth(it.year, it.month)
        })
    }
    val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
    val isWoman = viewModel.profile?.role == "woman"
    
    // State for day options bottom sheet
    var selectedDate by remember { mutableStateOf<LocalDate?>(null) }
    var showDayOptionsSheet by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.xl)
    ) {
        // Month navigation
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { currentMonth = currentMonth.minusMonths(1) }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = "Previous month",
                    tint = MomentTheme.colors.textSecondary
                )
            }
            
            Text(
                text = "${currentMonth.month.name.lowercase().replaceFirstChar { it.uppercase() }} ${currentMonth.year}",
                style = MaterialTheme.typography.headlineMedium,
                color = MomentTheme.colors.textPrimary
            )
            
            IconButton(onClick = { currentMonth = currentMonth.plusMonths(1) }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "Next month",
                    tint = MomentTheme.colors.textSecondary
                )
            }
        }
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Day of week headers
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun").forEach { day ->
                Text(
                    text = day,
                    style = MaterialTheme.typography.labelSmall,
                    color = MomentTheme.colors.textTertiary,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center
                )
            }
        }
        
        Spacer(modifier = Modifier.height(Spacing.sm))
        
        // Calendar grid
        val daysInMonth = getDaysInMonth(currentMonth)
        
        LazyVerticalGrid(
            columns = GridCells.Fixed(7),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs)
        ) {
            items(daysInMonth) { date ->
                if (date != null) {
                    // First try stored cycle days
                    val storedCycleDay = viewModel.cycleDays.find { it.date == date.toString() }
                    
                    // Calculate fertility (including future projection)
                    val fertilityLevel = storedCycleDay?.fertilityLevel?.let { 
                        FertilityLevel.valueOf(it.uppercase()) 
                    } ?: calculateFertilityForDate(date, viewModel)
                    
                    val hadIntimacy = storedCycleDay?.hadIntimacy == true
                    val isToday = date == today
                    val isMenstruation = storedCycleDay?.isMenstruation == true || 
                        calculateIsMenstruation(date, viewModel)
                    
                    CalendarDayCell(
                        date = date,
                        fertilityLevel = fertilityLevel,
                        hadIntimacy = hadIntimacy,
                        isToday = isToday,
                        isWoman = isWoman,
                        isMenstruation = isMenstruation,
                        onClick = { 
                            if (date <= today) {
                                selectedDate = date
                                showDayOptionsSheet = true
                            }
                        }
                    )
                } else {
                    Box(modifier = Modifier.aspectRatio(1f))
                }
            }
        }
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Legend
        CalendarLegend(isWoman = isWoman)
    }
    
    // Day options bottom sheet
    if (showDayOptionsSheet && selectedDate != null) {
        val sheetState = rememberModalBottomSheetState()
        val date = selectedDate!!
        val cycleDay = viewModel.cycleDays.find { it.date == date.toString() }
        val hasIntimacy = cycleDay?.hadIntimacy == true
        
        ModalBottomSheet(
            onDismissRequest = { showDayOptionsSheet = false },
            sheetState = sheetState,
            containerColor = MomentTheme.colors.cardBackground
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg)
                    .padding(bottom = Spacing.xxl)
            ) {
                // Date header
                Text(
                    text = "${date.dayOfMonth} ${date.month.name.lowercase().replaceFirstChar { it.uppercase() }} ${date.year}",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MomentTheme.colors.textPrimary,
                    modifier = Modifier.padding(bottom = Spacing.lg)
                )
                
                // Intimacy toggle option
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            viewModel.toggleIntimacy(date)
                            showDayOptionsSheet = false
                        }
                        .padding(vertical = Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md)
                ) {
                    Icon(
                        imageVector = if (hasIntimacy) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                        contentDescription = null,
                        tint = if (hasIntimacy) MomentTheme.colors.tertiary else MomentTheme.colors.textSecondary,
                        modifier = Modifier.size(24.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = if (hasIntimacy) "Remove intimacy" else "Log intimacy",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MomentTheme.colors.textPrimary
                        )
                        Text(
                            text = if (hasIntimacy) "Tap to remove from this day" else "Tap to mark this day",
                            style = MaterialTheme.typography.bodySmall,
                            color = MomentTheme.colors.textSecondary
                        )
                    }
                    if (hasIntimacy) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = MomentTheme.colors.success,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * Calculate fertility level for a date, including future projection.
 * This allows users to see predicted fertility windows for upcoming months.
 */
private fun calculateFertilityForDate(date: LocalDate, viewModel: AppViewModel): FertilityLevel? {
    val cycle = viewModel.currentCycle ?: return null
    
    // Parse the cycle start date
    val cycleStart = try {
        LocalDate.parse(cycle.startDate)
    } catch (e: Exception) {
        return null
    }
    
    // Days since cycle start
    val daysSinceStart = cycleStart.daysUntil(date)
    
    // Before cycle start - no fertility data
    if (daysSinceStart < 0) return null
    
    val cycleLength = cycle.cycleLength
    // Use cycle's luteal length, or profile's average, or default to 14
    val lutealLength = cycle.lutealLength.takeIf { it > 0 } 
        ?: viewModel.profile?.averageLutealLength 
        ?: 14
    
    // Calculate ovulation and fertile window
    val ovulationDay = maxOf(1, cycleLength - lutealLength)
    val fertileStart = maxOf(1, ovulationDay - 5)
    val fertileEnd = minOf(cycleLength, ovulationDay + 1)
    
    // Calculate which day in the (potentially projected) cycle this is
    val dayInCycle = if (daysSinceStart < cycleLength) {
        // Within current cycle
        daysSinceStart + 1
    } else {
        // Future projection - use modulo to wrap around
        ((daysSinceStart) % cycleLength) + 1
    }
    
    // Determine fertility level
    return when {
        dayInCycle >= fertileStart && dayInCycle <= fertileEnd -> {
            if (dayInCycle == ovulationDay || dayInCycle == ovulationDay - 1) {
                FertilityLevel.PEAK
            } else {
                FertilityLevel.HIGH
            }
        }
        else -> FertilityLevel.LOW
    }
}

/**
 * Calculate if a date is during menstruation (first 5 days of cycle).
 */
private fun calculateIsMenstruation(date: LocalDate, viewModel: AppViewModel): Boolean {
    val cycle = viewModel.currentCycle ?: return false
    
    // Parse the cycle start date
    val cycleStart = try {
        LocalDate.parse(cycle.startDate)
    } catch (e: Exception) {
        return false
    }
    
    val daysSinceStart = cycleStart.daysUntil(date)
    if (daysSinceStart < 0) return false
    
    val cycleLength = cycle.cycleLength
    
    // Calculate day in (potentially projected) cycle
    val dayInCycle = if (daysSinceStart < cycleLength) {
        daysSinceStart + 1
    } else {
        ((daysSinceStart) % cycleLength) + 1
    }
    
    return dayInCycle <= 5
}

@Composable
private fun CalendarDayCell(
    date: LocalDate,
    fertilityLevel: FertilityLevel?,
    hadIntimacy: Boolean,
    isToday: Boolean,
    isWoman: Boolean,
    isMenstruation: Boolean = false,
    onClick: () -> Unit
) {
    // Woman sees menstruation (rose color), partner doesn't
    val backgroundColor = when {
        isWoman && isMenstruation -> MomentTheme.colors.tertiary.copy(alpha = 0.3f)
        fertilityLevel == FertilityLevel.LOW -> if (isWoman) MomentTheme.colors.fertilityLow else MomentTheme.colors.partnerLow
        fertilityLevel == FertilityLevel.HIGH -> if (isWoman) MomentTheme.colors.fertilityHigh else MomentTheme.colors.partnerHigh
        fertilityLevel == FertilityLevel.PEAK -> if (isWoman) MomentTheme.colors.fertilityPeak else MomentTheme.colors.partnerPeak
        else -> Color.Transparent
    }
    
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clip(CircleShape)
            .background(backgroundColor)
            .then(
                if (isToday) Modifier.border(2.dp, MomentTheme.colors.primary, CircleShape)
                else Modifier
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = date.dayOfMonth.toString(),
                style = MaterialTheme.typography.bodyMedium,
                color = if (fertilityLevel != null || isMenstruation) MomentTheme.colors.textPrimary 
                       else MomentTheme.colors.textSecondary
            )
            
            if (hadIntimacy) {
                Icon(
                    imageVector = Icons.Default.Favorite,
                    contentDescription = "Intimacy logged",
                    modifier = Modifier.size(10.dp),
                    tint = MomentTheme.colors.tertiary
                )
            }
        }
    }
}

@Composable
private fun CalendarLegend(isWoman: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        LegendItem(
            color = if (isWoman) MomentTheme.colors.fertilityPeak else MomentTheme.colors.partnerPeak,
            label = "Peak"
        )
        LegendItem(
            color = if (isWoman) MomentTheme.colors.fertilityHigh else MomentTheme.colors.partnerHigh,
            label = "High"
        )
        LegendItem(
            color = if (isWoman) MomentTheme.colors.fertilityLow else MomentTheme.colors.partnerLow,
            label = "Low"
        )
        if (isWoman) {
            LegendItem(
                color = MomentTheme.colors.tertiary.copy(alpha = 0.5f),
                label = "Period"
            )
        }
        // Intimacy indicator
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = MomentTheme.colors.tertiary
            )
            Text(
                text = "Intimacy",
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.textSecondary
            )
        }
    }
}

@Composable
private fun LegendItem(
    color: Color,
    label: String
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MomentTheme.colors.textSecondary
        )
    }
}

// Helper class for year-month
data class YearMonth(val year: Int, val month: Month) {
    fun minusMonths(months: Int): YearMonth {
        var newMonth = this.month.ordinal - months
        var newYear = this.year
        while (newMonth < 0) {
            newMonth += 12
            newYear--
        }
        return YearMonth(newYear, Month.entries[newMonth])
    }
    
    fun plusMonths(months: Int): YearMonth {
        var newMonth = this.month.ordinal + months
        var newYear = this.year
        while (newMonth > 11) {
            newMonth -= 12
            newYear++
        }
        return YearMonth(newYear, Month.entries[newMonth])
    }
}

private fun getDaysInMonth(yearMonth: YearMonth): List<LocalDate?> {
    val firstDayOfMonth = LocalDate(yearMonth.year, yearMonth.month, 1)
    val daysInMonth = when (yearMonth.month) {
        Month.JANUARY, Month.MARCH, Month.MAY, Month.JULY, 
        Month.AUGUST, Month.OCTOBER, Month.DECEMBER -> 31
        Month.APRIL, Month.JUNE, Month.SEPTEMBER, Month.NOVEMBER -> 30
        Month.FEBRUARY -> if (yearMonth.year % 4 == 0 && 
                              (yearMonth.year % 100 != 0 || yearMonth.year % 400 == 0)) 29 else 28
    }
    
    // Monday = 1, Sunday = 7 in ISO
    val firstDayOfWeek = firstDayOfMonth.dayOfWeek.ordinal // 0 = Monday
    
    val days = mutableListOf<LocalDate?>()
    
    // Add empty cells for days before the 1st
    repeat(firstDayOfWeek) { days.add(null) }
    
    // Add actual days
    for (day in 1..daysInMonth) {
        days.add(LocalDate(yearMonth.year, yearMonth.month, day))
    }
    
    return days
}
