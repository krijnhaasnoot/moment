package com.moment.app.ui.onboarding

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.moment.app.data.model.NotificationTone
import com.moment.app.data.model.UserRole
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import com.moment.app.viewmodel.OnboardingStep

@Composable
fun OnboardingScreen(viewModel: AppViewModel) {
    AnimatedContent(
        targetState = viewModel.onboardingStep,
        transitionSpec = {
            slideInHorizontally { it } + fadeIn() togetherWith 
            slideOutHorizontally { -it } + fadeOut()
        },
        label = "onboarding_transition"
    ) { step ->
        when (step) {
            OnboardingStep.WELCOME -> WelcomeScreen(viewModel)
            OnboardingStep.SELECT_ROLE -> SelectRoleScreen(viewModel)
            OnboardingStep.ENTER_NAME -> EnterNameScreen(viewModel)
            OnboardingStep.PARTNER_CHOICE -> PartnerChoiceScreen(viewModel)
            OnboardingStep.ENTER_INVITE_CODE -> EnterInviteCodeScreen(viewModel)
            OnboardingStep.SELECT_TONE -> SelectToneScreen(viewModel)
            OnboardingStep.INVITE_PARTNER -> InvitePartnerScreen(viewModel)
            OnboardingStep.INVITE_MOTHER -> InviteMotherScreen(viewModel)
        }
    }
}

@Composable
private fun WelcomeScreen(viewModel: AppViewModel) {
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
            
            // Logo
            Box(
                modifier = Modifier
                    .size(160.dp)
                    .clip(CircleShape)
                    .background(MomentTheme.colors.primary.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(120.dp)
                        .clip(CircleShape)
                        .background(MomentTheme.colors.primary.copy(alpha = 0.25f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Favorite,
                        contentDescription = null,
                        modifier = Modifier.size(60.dp),
                        tint = MomentTheme.colors.primary
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            Text(
                text = "Moment",
                style = MaterialTheme.typography.displayMedium,
                color = MomentTheme.colors.textPrimary
            )
            
            Text(
                text = "Timing, together",
                style = MaterialTheme.typography.bodyLarge,
                color = MomentTheme.colors.textTertiary
            )
            
            Spacer(modifier = Modifier.weight(1f))
            
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                Text(
                    text = "A gentle guide for couples\ntrying to conceive.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MomentTheme.colors.textSecondary,
                    textAlign = TextAlign.Center
                )
                
                Text(
                    text = "No pressure. Just clarity.",
                    style = MaterialTheme.typography.labelLarge,
                    color = MomentTheme.colors.textPrimary
                )
            }
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
            
            MomentPrimaryButton(
                text = "Get Started",
                onClick = { viewModel.completeWelcome() }
            )
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
        }
    }
}

@Composable
private fun SelectRoleScreen(viewModel: AppViewModel) {
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
            
            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                Text(
                    text = "Who's setting up?",
                    style = MaterialTheme.typography.displaySmall,
                    color = MomentTheme.colors.textPrimary
                )
                
                Text(
                    text = "Moment helps couples track fertility together.\nChoose your role to get started.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MomentTheme.colors.textSecondary,
                    textAlign = TextAlign.Center
                )
            }
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            // Options
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                OptionCard(
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = null,
                            modifier = Modifier.size(28.dp),
                            tint = MomentTheme.colors.primary
                        )
                    },
                    title = "I'm tracking my cycle",
                    subtitle = "Log your cycle, track fertility, and invite your partner to follow along",
                    onClick = { viewModel.selectRole(UserRole.WOMAN) }
                )
                
                OptionCard(
                    icon = {
                        Icon(
                            imageVector = Icons.Default.People,
                            contentDescription = null,
                            modifier = Modifier.size(28.dp),
                            tint = MomentTheme.colors.primary
                        )
                    },
                    title = "I'm the partner",
                    subtitle = "Connect with your partner's cycle and receive fertility updates",
                    onClick = { viewModel.selectRole(UserRole.PARTNER) }
                )
            }
            
            Spacer(modifier = Modifier.height(Spacing.lg))
            
            // Helper text
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MomentTheme.colors.textTertiary
                )
                Text(
                    text = "Not sure? The person with the cycle should choose the first option.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textTertiary
                )
            }
            
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun EnterNameScreen(viewModel: AppViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
    ) {
        // Back button
        IconButton(
            onClick = { 
                viewModel.clearError()
                viewModel.goBackInOnboarding() 
            },
            modifier = Modifier.padding(top = Spacing.md)
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MomentTheme.colors.textTertiary
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "What should we\ncall you?",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )
            
            Text(
                text = "This is just for your partner to see",
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.textSecondary,
                modifier = Modifier.padding(top = Spacing.xs)
            )
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            MomentTextField(
                value = viewModel.userName,
                onValueChange = { viewModel.userName = it },
                placeholder = "Your name"
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        viewModel.errorMessage?.let { error ->
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.error,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = Spacing.md)
            )
        }
        
        MomentPrimaryButton(
            text = "Continue",
            onClick = { viewModel.submitName() },
            enabled = viewModel.userName.isNotBlank(),
            isLoading = viewModel.isLoading
        )
        
        Spacer(modifier = Modifier.height(Spacing.xxl))
    }
}

@Composable
private fun PartnerChoiceScreen(viewModel: AppViewModel) {
    val isWoman = viewModel.selectedRole == UserRole.WOMAN
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
    ) {
        // Back button
        IconButton(
            onClick = { 
                viewModel.clearError()
                viewModel.goBackInOnboarding() 
            },
            modifier = Modifier.padding(top = Spacing.md)
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MomentTheme.colors.textTertiary
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            Text(
                text = "How would you like\nto connect?",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )
            
            Text(
                text = if (isWoman) "Connect with your partner to share your fertility updates."
                       else "Connect with your partner to follow their fertility journey.",
                style = MaterialTheme.typography.bodyMedium,
                color = MomentTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
        
        Spacer(modifier = Modifier.height(Spacing.xl))
        
        Column(
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            OptionCard(
                icon = {
                    Icon(
                        imageVector = Icons.Default.Email,
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = MomentTheme.colors.primary
                    )
                },
                title = "I have an invite code",
                subtitle = "Your partner already set up Moment and shared a 6-digit code with you",
                onClick = { viewModel.chooseJoinWithCode() }
            )
            
            OptionCard(
                icon = {
                    Icon(
                        imageVector = if (isWoman) Icons.Default.CalendarMonth else Icons.Default.PersonAdd,
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = MomentTheme.colors.primary
                    )
                },
                title = if (isWoman) "I'll start tracking" else "I'll invite my partner",
                subtitle = if (isWoman) "Start fresh and create a code to invite your partner later"
                          else "Create a code and share it with your partner to connect",
                onClick = { viewModel.chooseCreateInvite() }
            )
        }
        
        Spacer(modifier = Modifier.height(Spacing.lg))
        
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Lightbulb,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = MomentTheme.colors.textTertiary
            )
            Text(
                text = if (isWoman) "Tip: If you're the first one setting up, choose the second option."
                       else "Tip: If your partner hasn't set up yet, choose the second option.",
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.textTertiary
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun EnterInviteCodeScreen(viewModel: AppViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
    ) {
        // Back button at top
        IconButton(
            onClick = { 
                viewModel.clearError()
                viewModel.goBackInOnboarding() 
            },
            modifier = Modifier.padding(top = Spacing.md)
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MomentTheme.colors.textTertiary
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Enter your\ninvite code",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )
            
            Text(
                text = "Ask your partner for the 6-digit code",
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.textSecondary,
                modifier = Modifier.padding(top = Spacing.xs)
            )
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            MomentTextField(
                value = viewModel.inviteCode,
                onValueChange = { 
                    viewModel.inviteCode = it.uppercase().take(6)
                },
                placeholder = "XXXXXX"
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        viewModel.errorMessage?.let { error ->
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.error,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = Spacing.md)
            )
        }
        
        MomentPrimaryButton(
            text = "Join",
            onClick = { viewModel.joinWithInviteCode() },
            enabled = viewModel.inviteCode.length == 6,
            isLoading = viewModel.isLoading
        )
        
        Spacer(modifier = Modifier.height(Spacing.xxl))
    }
}

@Composable
private fun SelectToneScreen(viewModel: AppViewModel) {
    var selectedTone by remember { mutableStateOf(NotificationTone.DISCREET) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
            .padding(horizontal = Spacing.lg)
    ) {
        // Back button
        IconButton(
            onClick = { 
                viewModel.clearError()
                viewModel.goBackInOnboarding() 
            },
            modifier = Modifier.padding(top = Spacing.md)
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MomentTheme.colors.textTertiary
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "How should we notify\nyour partner?",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                NotificationTone.entries.forEach { tone ->
                    ToneOptionCard(
                        tone = tone,
                        isSelected = selectedTone == tone,
                        onClick = { selectedTone = tone }
                    )
                }
            }
            
            Text(
                text = "You can change this anytime in settings",
                style = MaterialTheme.typography.bodySmall,
                color = MomentTheme.colors.textSecondary,
                modifier = Modifier.padding(top = Spacing.lg)
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        MomentPrimaryButton(
            text = "Continue",
            onClick = { viewModel.selectNotificationTone(selectedTone) }
        )
        
        Spacer(modifier = Modifier.height(Spacing.xxl))
    }
}

@Composable
private fun ToneOptionCard(
    tone: NotificationTone,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(CornerRadius.large),
        colors = CardDefaults.cardColors(
            containerColor = MomentTheme.colors.cardBackground
        ),
        border = if (isSelected) CardDefaults.outlinedCardBorder().copy(
            width = 2.dp,
            brush = androidx.compose.ui.graphics.SolidColor(MomentTheme.colors.primary)
        ) else null
    ) {
        Row(
            modifier = Modifier.padding(Spacing.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            RadioButton(
                selected = isSelected,
                onClick = onClick,
                colors = RadioButtonDefaults.colors(
                    selectedColor = MomentTheme.colors.primary
                )
            )
            
            Column {
                Text(
                    text = tone.displayName,
                    style = MaterialTheme.typography.headlineSmall,
                    color = MomentTheme.colors.textPrimary
                )
                Text(
                    text = tone.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textSecondary
                )
            }
        }
    }
}

@Composable
private fun InvitePartnerScreen(viewModel: AppViewModel) {
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
                text = "Invite your partner",
                style = MaterialTheme.typography.displaySmall,
                color = MomentTheme.colors.textPrimary
            )
            
            Text(
                text = "Share this code so they can join and start tracking",
                style = MaterialTheme.typography.bodyMedium,
                color = MomentTheme.colors.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = Spacing.xs)
            )
            
            Spacer(modifier = Modifier.height(Spacing.xl))
            
            // Code card
            MomentCard {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Spacing.md)
                ) {
                    Text(
                        text = "Your invite code",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                    
                    Text(
                        text = viewModel.partnerInviteCode,
                        style = MaterialTheme.typography.displayMedium,
                        color = MomentTheme.colors.textPrimary,
                        letterSpacing = 4.sp
                    )
                    
                    TextButton(onClick = { /* Copy to clipboard */ }) {
                        Icon(
                            imageVector = Icons.Default.ContentCopy,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(Spacing.xs))
                        Text("Copy")
                    }
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                MomentSecondaryButton(
                    text = "Share Code",
                    onClick = { /* Share */ }
                )
                
                MomentPrimaryButton(
                    text = "Continue",
                    onClick = { viewModel.skipPartnerInvite() }
                )
                
                Text(
                    text = "Your partner will need to download Moment and use this code",
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = Spacing.xs)
                )
            }
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
        }
    }
}

@Composable
private fun InviteMotherScreen(viewModel: AppViewModel) {
    // Same as InvitePartnerScreen but for partner inviting woman
    InvitePartnerScreen(viewModel)
}
