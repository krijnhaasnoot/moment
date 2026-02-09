package com.moment.app.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import kotlinx.datetime.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SetupCycleScreen(viewModel: AppViewModel) {
    var cycleLength by remember { mutableIntStateOf(28) }
    var showDatePicker by remember { mutableStateOf(false) }
    var selectedDate by remember { 
        mutableStateOf(Clock.System.todayIn(TimeZone.currentSystemDefault()))
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.weight(1f))
            
            Text(
                text = "Let's set up\nyour cycle",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )
            
            Text(
                text = "This helps us calculate your fertile window",
                style = MaterialTheme.typography.bodyMedium,
                color = MomentTheme.colors.textSecondary,
                modifier = Modifier.padding(top = Spacing.xs)
            )
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
            
            // Last period start date
            MomentCard {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                ) {
                    Text(
                        text = "When did your last period start?",
                        style = MaterialTheme.typography.labelLarge,
                        color = MomentTheme.colors.textPrimary
                    )
                    
                    OutlinedButton(
                        onClick = { showDatePicker = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = formatDate(selectedDate),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(Spacing.md))
            
            // Cycle length
            MomentCard {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                ) {
                    Text(
                        text = "Average cycle length",
                        style = MaterialTheme.typography.labelLarge,
                        color = MomentTheme.colors.textPrimary
                    )
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        IconButton(
                            onClick = { if (cycleLength > 21) cycleLength-- }
                        ) {
                            Text(
                                text = "−",
                                style = MaterialTheme.typography.headlineMedium,
                                color = MomentTheme.colors.primary
                            )
                        }
                        
                        Text(
                            text = "$cycleLength days",
                            style = MaterialTheme.typography.headlineMedium,
                            color = MomentTheme.colors.textPrimary
                        )
                        
                        IconButton(
                            onClick = { if (cycleLength < 45) cycleLength++ }
                        ) {
                            Text(
                                text = "+",
                                style = MaterialTheme.typography.headlineMedium,
                                color = MomentTheme.colors.primary
                            )
                        }
                    }
                    
                    Text(
                        text = "Most cycles are 21-35 days",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary,
                        modifier = Modifier.align(Alignment.CenterHorizontally)
                    )
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            viewModel.errorMessage?.let { error ->
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.error,
                    modifier = Modifier.padding(bottom = Spacing.md)
                )
            }
            
            MomentPrimaryButton(
                text = "Start Tracking",
                onClick = { viewModel.createCycle(selectedDate, cycleLength) },
                isLoading = viewModel.isLoading
            )
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
        }
    }
    
    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = selectedDate.toEpochDays() * 24 * 60 * 60 * 1000L
        )
        
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        selectedDate = Instant.fromEpochMilliseconds(millis)
                            .toLocalDateTime(TimeZone.currentSystemDefault())
                            .date
                    }
                    showDatePicker = false
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

private fun formatDate(date: LocalDate): String {
    val month = date.month.name.lowercase().replaceFirstChar { it.uppercase() }
    return "${month.take(3)} ${date.dayOfMonth}, ${date.year}"
}
