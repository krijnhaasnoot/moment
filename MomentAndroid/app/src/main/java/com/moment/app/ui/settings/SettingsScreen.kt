package com.moment.app.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.CachePolicy
import coil.request.ImageRequest
import com.moment.app.data.model.TemperatureUnit
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.todayIn
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(viewModel: AppViewModel) {
    val scrollState = rememberScrollState()
    var showLegalDisclaimer by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .verticalScroll(scrollState)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.xl)
    ) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.headlineMedium,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        // Profile section
        ProfileSection(viewModel)
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Couple section
        CoupleSection(viewModel)
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Notifications section
        NotificationsSection(viewModel)
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Cycle management section (woman only)
        if (viewModel.profile?.role == "woman") {
            CycleManagementSection(viewModel)
            
            Spacer(modifier = Modifier.height(Spacing.lg))
        }
        
        // Optional tracking section (woman only)
        if (viewModel.profile?.role == "woman") {
            OptionalTrackingSection(viewModel)
            
            Spacer(modifier = Modifier.height(Spacing.lg))
        }
        
        // App info section
        AppInfoSection()
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Medical disclaimer
        DisclaimerSection(onReadMoreClick = { showLegalDisclaimer = true })
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Kinder app link
        KinderAppSection()
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        // Footer
        Text(
            text = "Moment is not a medical device.",
            style = MaterialTheme.typography.bodySmall,
            color = MomentTheme.colors.textSecondary,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        // Sign out
        OutlinedButton(
            onClick = { viewModel.signOut() },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MomentTheme.colors.error
            )
        ) {
            Icon(
                imageVector = Icons.Default.Logout,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(Spacing.sm))
            Text("Sign Out")
        }
        
        Spacer(modifier = Modifier.height(Spacing.xxl))
    }
    
    // Legal Disclaimer Bottom Sheet
    if (showLegalDisclaimer) {
        ModalBottomSheet(
            onDismissRequest = { showLegalDisclaimer = false },
            containerColor = MomentTheme.colors.cardBackground
        ) {
            LegalDisclaimerContent()
        }
    }
}

@Composable
private fun LegalDisclaimerContent() {
    val scrollState = rememberScrollState()
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scrollState)
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xxl)
    ) {
        Text(
            text = "Legal Disclaimer",
            style = MaterialTheme.typography.headlineSmall,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Medical Disclaimer
        DisclaimerItem(
            title = "Medical Disclaimer",
            content = "The information provided by Moment is for educational and informational purposes only and is not intended to be medical advice, diagnosis, or treatment.\n\nMoment does not provide medical, clinical, or professional healthcare services. Always seek the advice of a qualified healthcare professional regarding fertility, reproductive health, pregnancy, contraception, or any related medical condition. Never disregard or delay professional medical advice because of information provided by Moment."
        )
        
        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.md))
        
        // No Guarantee Disclaimer
        DisclaimerItem(
            title = "No Guarantee Disclaimer",
            content = "Moment uses user-provided data, scientific research, and predictive algorithms to offer fertility insights and cycle estimates. However, accuracy cannot be guaranteed. Menstrual cycles, ovulation timing, and fertility outcomes can vary widely between individuals and from cycle to cycle.\n\nMoment does not guarantee conception, pregnancy prevention, or any specific health outcome."
        )
        
        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.md))
        
        // Not a Contraceptive or Diagnostic Tool
        DisclaimerItem(
            title = "Not a Contraceptive or Diagnostic Tool",
            content = "Moment is not intended to be used as a method of contraception and should not be relied upon to prevent pregnancy. It is also not a diagnostic tool and should not be used to identify or treat medical conditions."
        )
        
        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.md))
        
        // User Responsibility
        DisclaimerItem(
            title = "User Responsibility",
            content = "You are solely responsible for how you interpret and use the information provided by Moment. Any decisions regarding your health, fertility, or family planning are made at your own discretion and risk."
        )
        
        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.md))
        
        // Emergency Use Disclaimer
        DisclaimerItem(
            title = "Emergency Use Disclaimer",
            content = "Moment is not intended for use in medical emergencies. If you believe you are experiencing a medical emergency, contact your healthcare provider or local emergency services immediately."
        )
        
        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.md))
        
        // Limitation of Liability
        DisclaimerItem(
            title = "Limitation of Liability",
            content = "To the fullest extent permitted by law, Moment, its creators, and affiliates shall not be liable for any direct, indirect, incidental, consequential, or special damages arising from the use of, or inability to use, the app or its content."
        )
    }
}

@Composable
private fun DisclaimerItem(title: String, content: String) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MomentTheme.colors.textPrimary
        )
        Text(
            text = content,
            style = MaterialTheme.typography.bodyMedium,
            color = MomentTheme.colors.textSecondary
        )
    }
}

@Composable
private fun ProfileSection(viewModel: AppViewModel) {
    val context = LocalContext.current
    var showEditNameDialog by remember { mutableStateOf(false) }
    var editedName by remember { mutableStateOf(viewModel.profile?.name ?: "") }
    var isUploading by remember { mutableStateOf(false) }
    
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri != null) {
            isUploading = true
            viewModel.uploadProfilePhoto(context, uri) {
                isUploading = false
            }
        }
    }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Profile",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Profile photo - clickable to change
                Box(
                    modifier = Modifier
                        .size(56.dp) // Slightly larger to accommodate badge
                        .clickable(enabled = !isUploading) { 
                            photoPickerLauncher.launch("image/*") 
                        },
                    contentAlignment = Alignment.Center
                ) {
                    // Photo circle
                    Box(
                        modifier = Modifier
                            .size(50.dp)
                            .clip(CircleShape)
                            .background(MomentTheme.colors.primary.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isUploading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(24.dp),
                                strokeWidth = 2.dp,
                                color = MomentTheme.colors.primary
                            )
                        } else {
                            val photoUrl = viewModel.profile?.profilePhotoUrl
                            if (!photoUrl.isNullOrEmpty()) {
                                android.util.Log.d("ProfileSection", "Loading photo from: $photoUrl")
                                AsyncImage(
                                    model = ImageRequest.Builder(context)
                                        .data(photoUrl)
                                        .crossfade(true)
                                        .memoryCachePolicy(CachePolicy.DISABLED)
                                        .diskCachePolicy(CachePolicy.DISABLED)
                                        .listener(
                                            onError = { _, result ->
                                                android.util.Log.e("ProfileSection", "Failed to load image: ${result.throwable.message}")
                                            },
                                            onSuccess = { _, _ ->
                                                android.util.Log.d("ProfileSection", "Image loaded successfully")
                                            }
                                        )
                                        .build(),
                                    contentDescription = "Profile photo",
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .clip(CircleShape),
                                    contentScale = ContentScale.Crop
                                )
                            } else {
                                Text(
                                    text = viewModel.profile?.name?.firstOrNull()?.uppercase() ?: "?",
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = MomentTheme.colors.primary
                                )
                            }
                        }
                    }
                    
                    // Camera badge - positioned outside the clip
                    if (!isUploading) {
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .size(18.dp)
                                .clip(CircleShape)
                                .background(MomentTheme.colors.primary),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.CameraAlt,
                                contentDescription = "Change photo",
                                modifier = Modifier.size(10.dp),
                                tint = MomentTheme.colors.cardBackground
                            )
                        }
                    }
                }
                
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = viewModel.profile?.name ?: "",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MomentTheme.colors.textPrimary
                    )
                    Text(
                        text = if (viewModel.profile?.role == "woman") "Tracking my cycle" else "Partner",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                }
                
                IconButton(onClick = { 
                    editedName = viewModel.profile?.name ?: ""
                    showEditNameDialog = true 
                }) {
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = "Edit name",
                        tint = MomentTheme.colors.textTertiary
                    )
                }
            }
        }
    }
    
    // Edit name dialog
    if (showEditNameDialog) {
        AlertDialog(
            onDismissRequest = { showEditNameDialog = false },
            title = { Text("Edit Name") },
            text = {
                OutlinedTextField(
                    value = editedName,
                    onValueChange = { editedName = it },
                    label = { Text("Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.updateProfileName(editedName)
                        showEditNameDialog = false
                    },
                    enabled = editedName.isNotBlank()
                ) {
                    Text("Save")
                }
            },
            dismissButton = {
                TextButton(onClick = { showEditNameDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun CoupleSection(viewModel: AppViewModel) {
    val context = LocalContext.current
    val clipboardManager = remember { 
        context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager 
    }
    var showCopiedToast by remember { mutableStateOf(false) }
    var showDisconnectDialog by remember { mutableStateOf(false) }
    var isDisconnecting by remember { mutableStateOf(false) }
    
    // Track loading state from viewModel
    val isLoadingCode = viewModel.isLoadingInviteCode
    val inviteCode = viewModel.partnerInviteCode
    
    // Load invite code when section appears and code is not yet available
    LaunchedEffect(Unit) {
        if (inviteCode.isEmpty() && !viewModel.isConnected) {
            viewModel.loadInviteCode()
        }
    }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Couple",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                if (viewModel.isConnected) {
                    // Connected state
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = MomentTheme.colors.success,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(Spacing.md))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Connected with ${viewModel.partnerName ?: "partner"}",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MomentTheme.colors.textPrimary
                            )
                            Text(
                                text = "Sharing fertility updates",
                                style = MaterialTheme.typography.bodySmall,
                                color = MomentTheme.colors.textSecondary
                            )
                        }
                        TextButton(
                            onClick = { showDisconnectDialog = true },
                            enabled = !isDisconnecting
                        ) {
                            if (isDisconnecting) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp
                                )
                            } else {
                                Text(
                                    text = "Disconnect",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MomentTheme.colors.textSecondary
                                )
                            }
                        }
                    }
                } else {
                    // Not connected state - show invite code
                    Column(
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PersonAdd,
                                contentDescription = null,
                                tint = MomentTheme.colors.textSecondary,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = "Invite your partner",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MomentTheme.colors.textPrimary
                            )
                        }
                        
                        if (isLoadingCode) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                            ) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp,
                                    color = MomentTheme.colors.primary
                                )
                                Text(
                                    text = "Loading invite code...",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MomentTheme.colors.textSecondary
                                )
                            }
                        } else if (viewModel.partnerInviteCode.isNotEmpty()) {
                            Text(
                                text = "Share this code with your partner:",
                                style = MaterialTheme.typography.bodySmall,
                                color = MomentTheme.colors.textSecondary
                            )
                            
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                // Large invite code display
                                Text(
                                    text = viewModel.partnerInviteCode,
                                    style = MaterialTheme.typography.headlineLarge,
                                    color = MomentTheme.colors.primary,
                                    letterSpacing = 4.sp
                                )
                                
                                // Copy button
                                IconButton(
                                    onClick = {
                                        val clip = android.content.ClipData.newPlainText(
                                            "Moment Invite Code", 
                                            viewModel.partnerInviteCode
                                        )
                                        clipboardManager.setPrimaryClip(clip)
                                        showCopiedToast = true
                                    }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.ContentCopy,
                                        contentDescription = "Copy code",
                                        tint = MomentTheme.colors.primary
                                    )
                                }
                            }
                            
                            if (showCopiedToast) {
                                LaunchedEffect(showCopiedToast) {
                                    kotlinx.coroutines.delay(2000)
                                    showCopiedToast = false
                                }
                                Text(
                                    text = "Code copied!",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MomentTheme.colors.success
                                )
                            }
                        } else {
                            // No invite code and not loading - show retry option
                            Column(
                                verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                            ) {
                                Text(
                                    text = "Tap to load your invite code",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MomentTheme.colors.textSecondary
                                )
                                
                                Button(
                                    onClick = { viewModel.loadInviteCode() },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = MomentTheme.colors.primary
                                    )
                                ) {
                                    Text("Load Invite Code")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Disconnect confirmation dialog
    if (showDisconnectDialog) {
        AlertDialog(
            onDismissRequest = { showDisconnectDialog = false },
            title = { Text("Disconnect Partner") },
            text = { 
                Text("This will disconnect you from your partner. You can reconnect later using a new invite code.") 
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        isDisconnecting = true
                        viewModel.disconnectPartner {
                            isDisconnecting = false
                            showDisconnectDialog = false
                        }
                    }
                ) {
                    Text("Disconnect", color = MomentTheme.colors.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDisconnectDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun NotificationsSection(viewModel: AppViewModel) {
    var notificationsEnabled by remember { 
        mutableStateOf(viewModel.profile?.notificationsEnabled ?: true) 
    }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Notifications",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    Text(
                        text = "Push notifications",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MomentTheme.colors.textPrimary
                    )
                    Text(
                        text = "Receive fertility updates",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                }
                
                Switch(
                    checked = notificationsEnabled,
                    onCheckedChange = { notificationsEnabled = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = MomentTheme.colors.cardBackground,
                        checkedTrackColor = MomentTheme.colors.primary
                    )
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OptionalTrackingSection(viewModel: AppViewModel) {
    var temperatureEnabled by remember { mutableStateOf(viewModel.isTemperatureTrackingEnabled) }
    var showTemperatureInfo by remember { mutableStateOf(false) }
    var selectedUnit by remember { mutableStateOf(viewModel.temperatureUnit) }
    
    // Update local state when profile changes
    LaunchedEffect(viewModel.profile) {
        temperatureEnabled = viewModel.isTemperatureTrackingEnabled
        selectedUnit = viewModel.temperatureUnit
    }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Optional tracking",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Temperature tracking toggle
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Track basal body temperature",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MomentTheme.colors.textPrimary
                        )
                        Text(
                            text = "Optional. Only enable this if you already track temperature and feel comfortable doing so.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MomentTheme.colors.textSecondary
                        )
                    }
                    
                    Spacer(modifier = Modifier.width(Spacing.md))
                    
                    Switch(
                        checked = temperatureEnabled,
                        onCheckedChange = { newValue ->
                            if (newValue) {
                                // Check if user has seen the info screen
                                if (!viewModel.hasAcknowledgedTemperatureInfo) {
                                    showTemperatureInfo = true
                                } else {
                                    temperatureEnabled = true
                                    viewModel.setTemperatureTracking(true)
                                }
                            } else {
                                temperatureEnabled = false
                                viewModel.setTemperatureTracking(false)
                            }
                        },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = MomentTheme.colors.cardBackground,
                            checkedTrackColor = MomentTheme.colors.primary
                        )
                    )
                }
                
                // Temperature unit picker (only shown when enabled)
                if (temperatureEnabled) {
                    HorizontalDivider(color = MomentTheme.colors.divider)
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Temperature unit",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MomentTheme.colors.textPrimary
                        )
                        
                        // Unit toggle
                        Row {
                            FilterChip(
                                selected = selectedUnit == TemperatureUnit.CELSIUS,
                                onClick = {
                                    selectedUnit = TemperatureUnit.CELSIUS
                                    viewModel.setTemperatureUnit(TemperatureUnit.CELSIUS)
                                },
                                label = { Text("Celsius") }
                            )
                            Spacer(modifier = Modifier.width(Spacing.sm))
                            FilterChip(
                                selected = selectedUnit == TemperatureUnit.FAHRENHEIT,
                                onClick = {
                                    selectedUnit = TemperatureUnit.FAHRENHEIT
                                    viewModel.setTemperatureUnit(TemperatureUnit.FAHRENHEIT)
                                },
                                label = { Text("Fahrenheit") }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Temperature info bottom sheet
    if (showTemperatureInfo) {
        ModalBottomSheet(
            onDismissRequest = { 
                showTemperatureInfo = false
                temperatureEnabled = false
            },
            containerColor = MomentTheme.colors.background
        ) {
            TemperatureInfoContent(
                onAcknowledge = {
                    viewModel.acknowledgeTemperatureInfo()
                    viewModel.setTemperatureTracking(true)
                    temperatureEnabled = true
                    showTemperatureInfo = false
                },
                onDismiss = {
                    showTemperatureInfo = false
                    temperatureEnabled = false
                }
            )
        }
    }
}

@Composable
private fun TemperatureInfoContent(
    onAcknowledge: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xxl)
    ) {
        // Title
        Text(
            text = "About temperature tracking",
            style = MaterialTheme.typography.headlineSmall,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Body text
        Text(
            text = "Some people choose to track basal body temperature to better understand their cycle.",
            style = MaterialTheme.typography.bodyMedium,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.md))
        
        Text(
            text = "This is optional and requires daily consistency. Moment will never require temperature input and will not remind you to log it.",
            style = MaterialTheme.typography.bodyMedium,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.md))
        
        Text(
            text = "Logged temperatures are used only as an additional signal to refine timing insights over time.",
            style = MaterialTheme.typography.bodyMedium,
            color = MomentTheme.colors.textPrimary
        )
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        // Footer
        Text(
            text = "Moment is not a medical device.",
            style = MaterialTheme.typography.bodySmall,
            color = MomentTheme.colors.textSecondary,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        // Button
        Button(
            onClick = onAcknowledge,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = MomentTheme.colors.primary
            )
        ) {
            Text("Got it")
        }
    }
}

@Composable
private fun AppInfoSection() {
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "About",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "Version",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textSecondary
                    )
                    Text(
                        text = "1.0.0",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textPrimary
                    )
                }
                
                HorizontalDivider(color = MomentTheme.colors.divider)
                
                TextButton(
                    onClick = { /* Open Terms */ },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Terms of Service",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.primary
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Icon(
                        imageVector = Icons.Default.OpenInNew,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = MomentTheme.colors.primary
                    )
                }
                
                TextButton(
                    onClick = { /* Open Privacy */ },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Privacy Policy",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.primary
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Icon(
                        imageVector = Icons.Default.OpenInNew,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = MomentTheme.colors.primary
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CycleManagementSection(viewModel: AppViewModel) {
    var showDatePicker by remember { mutableStateOf(false) }
    var showPeriodStartDialog by remember { mutableStateOf(false) }
    var isUpdating by remember { mutableStateOf(false) }
    
    val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
    val cycleStartDate = viewModel.currentCycle?.startDate
    
    // Calculate cycle day
    val cycleDay = if (cycleStartDate != null) {
        try {
            val startDate = kotlinx.datetime.LocalDate.parse(cycleStartDate)
            startDate.daysUntil(today) + 1
        } catch (e: Exception) { 0 }
    } else { 0 }
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Cycle",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Current cycle info
                if (cycleStartDate != null) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text(
                                text = "Current cycle",
                                style = MaterialTheme.typography.bodySmall,
                                color = MomentTheme.colors.textSecondary
                            )
                            Text(
                                text = "Day $cycleDay",
                                style = MaterialTheme.typography.headlineSmall,
                                color = MomentTheme.colors.textPrimary
                            )
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(
                                text = "Started",
                                style = MaterialTheme.typography.bodySmall,
                                color = MomentTheme.colors.textSecondary
                            )
                            Text(
                                text = cycleStartDate,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MomentTheme.colors.textPrimary
                            )
                        }
                    }
                    
                    HorizontalDivider(color = MomentTheme.colors.divider)
                }
                
                // Change cycle start date
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showDatePicker = true }
                        .padding(vertical = Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarMonth,
                        contentDescription = null,
                        tint = MomentTheme.colors.secondary,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(Spacing.sm))
                    Text(
                        text = "Change cycle start date",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = MomentTheme.colors.textSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
                
                HorizontalDivider(color = MomentTheme.colors.divider)
                
                // Period starts now button
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = !isUpdating) { showPeriodStartDialog = true }
                        .padding(vertical = Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.WaterDrop,
                        contentDescription = null,
                        tint = MomentTheme.colors.tertiary,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(Spacing.sm))
                    Text(
                        text = "My period started today",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    if (isUpdating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            }
        }
    }
    
    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = System.currentTimeMillis()
        )
        
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            viewModel.updateCycleStartDate(millis)
                        }
                        showDatePicker = false
                    }
                ) {
                    Text("Save")
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
    
    // Period start confirmation dialog
    if (showPeriodStartDialog) {
        AlertDialog(
            onDismissRequest = { showPeriodStartDialog = false },
            title = { Text("Start New Cycle") },
            text = { 
                Text("This will end your current cycle and start a new one from today. Your previous cycle data will be saved.") 
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        isUpdating = true
                        viewModel.startNewCycleToday()
                        showPeriodStartDialog = false
                        isUpdating = false
                    }
                ) {
                    Text("Yes, start new cycle")
                }
            },
            dismissButton = {
                TextButton(onClick = { showPeriodStartDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun DisclaimerSection(onReadMoreClick: () -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Medical Disclaimer",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                Text(
                    text = "Moment is not a medical device and does not provide medical advice. It is intended for informational purposes only and should not replace professional medical guidance.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textSecondary
                )
                
                TextButton(
                    onClick = onReadMoreClick,
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Text(
                        text = "Read more",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.primary
                    )
                }
            }
        }
    }
}

@Composable
private fun KinderAppSection() {
    val context = LocalContext.current
    
    Column(
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Our Other Apps",
            style = MaterialTheme.typography.labelLarge,
            color = MomentTheme.colors.textSecondary
        )
        
        MomentCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        // Open Kinder app in Play Store
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("https://play.google.com/store/apps/details?id=global.kinder")
                        }
                        context.startActivity(intent)
                    }
                    .padding(vertical = Spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Kinder app icon - load from Play Store
                AsyncImage(
                    model = "https://play-lh.googleusercontent.com/xlzCMXiUcVPgdZKnxrBbMIqlJtVka4s2pjTNFCWv3cXPqVdIJFu2C8tgkHaCMSsqtw=w240-h480-rw",
                    contentDescription = "Kinder app icon",
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
                
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Kinder",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MomentTheme.colors.textPrimary
                    )
                    Text(
                        text = "Find the perfect baby name together",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                }
                
                Icon(
                    imageVector = Icons.Default.OpenInNew,
                    contentDescription = null,
                    tint = MomentTheme.colors.primary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
