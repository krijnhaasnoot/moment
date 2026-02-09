package com.moment.app.ui.auth

import android.content.Context
import android.util.Log
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.FirebaseApp
import com.moment.app.R
import com.moment.app.ui.theme.*
import com.moment.app.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun AuthScreen(viewModel: AppViewModel) {
    var showEmailAuth by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MomentTheme.colors.background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .padding(horizontal = Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.weight(1f))
            
            // Logo
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .clip(CircleShape)
                    .background(MomentTheme.colors.primary.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Favorite,
                    contentDescription = null,
                    modifier = Modifier.size(50.dp),
                    tint = MomentTheme.colors.primary
                )
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
            
            // Auth buttons
            Column(
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Google Sign In
                GoogleSignInButton(
                    onClick = {
                        scope.launch {
                            signInWithGoogle(context, viewModel)
                        }
                    },
                    isLoading = viewModel.isLoading
                )
                
                // Divider
                Row(
                    modifier = Modifier.padding(vertical = Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    HorizontalDivider(
                        modifier = Modifier.weight(1f),
                        color = MomentTheme.colors.divider
                    )
                    Text(
                        text = "or",
                        modifier = Modifier.padding(horizontal = Spacing.sm),
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                    HorizontalDivider(
                        modifier = Modifier.weight(1f),
                        color = MomentTheme.colors.divider
                    )
                }
                
                // Email sign in
                MomentSecondaryButton(
                    text = "Continue with Email",
                    onClick = { showEmailAuth = true }
                )
                
                // Error message
                viewModel.errorMessage?.let { error ->
                    Text(
                        text = error,
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.error,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = Spacing.sm)
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(Spacing.xxl))
            
            // Terms & Privacy
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "By continuing, you agree to our",
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textSecondary
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xxs)
                ) {
                    TextButton(onClick = { /* Open Terms */ }) {
                        Text(
                            text = "Terms of Service",
                            style = MaterialTheme.typography.bodySmall,
                            color = MomentTheme.colors.primary
                        )
                    }
                    Text(
                        text = "and",
                        style = MaterialTheme.typography.bodySmall,
                        color = MomentTheme.colors.textSecondary
                    )
                    TextButton(onClick = { /* Open Privacy */ }) {
                        Text(
                            text = "Privacy Policy",
                            style = MaterialTheme.typography.bodySmall,
                            color = MomentTheme.colors.primary
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(Spacing.lg))
        }
    }
    
    // Email Auth Sheet
    if (showEmailAuth) {
        EmailAuthSheet(
            viewModel = viewModel,
            onDismiss = { showEmailAuth = false }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EmailAuthSheet(
    viewModel: AppViewModel,
    onDismiss: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    
    val isValid = email.isNotBlank() && email.contains("@") && password.length >= 6
    
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MomentTheme.colors.cardBackground,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        windowInsets = WindowInsets(0, 0, 0, 0)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 24.dp)
                .padding(bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Title
            Text(
                text = if (isSignUp) "Create Account" else "Sign In",
                style = MaterialTheme.typography.headlineSmall,
                color = MomentTheme.colors.textPrimary
            )
            
            Spacer(modifier = Modifier.height(20.dp))
            
            // Toggle tabs
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(RoundedCornerShape(CornerRadius.medium))
                    .background(MomentTheme.colors.background),
            ) {
                TabButton(
                    text = "Sign In",
                    isSelected = !isSignUp,
                    onClick = { isSignUp = false },
                    modifier = Modifier.weight(1f)
                )
                TabButton(
                    text = "Sign Up",
                    isSelected = isSignUp,
                    onClick = { isSignUp = true },
                    modifier = Modifier.weight(1f)
                )
            }
            
            Spacer(modifier = Modifier.height(20.dp))
            
            // Form fields
            MomentTextField(
                value = email,
                onValueChange = { email = it },
                placeholder = "Email",
                keyboardType = KeyboardType.Email
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            MomentTextField(
                value = password,
                onValueChange = { password = it },
                placeholder = "Password",
                isPassword = true
            )
            
            if (isSignUp) {
                Text(
                    text = "Password must be at least 6 characters",
                    style = MaterialTheme.typography.bodySmall,
                    color = MomentTheme.colors.textSecondary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp, start = 4.dp)
                )
            }
            
            // Error
            viewModel.errorMessage?.let { error ->
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MomentTheme.colors.error,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                )
            }
            
            Spacer(modifier = Modifier.height(20.dp))
            
            // Submit button
            MomentPrimaryButton(
                text = if (isSignUp) "Create Account" else "Sign In",
                onClick = {
                    if (isSignUp) {
                        viewModel.signUp(email, password)
                    } else {
                        viewModel.signIn(email, password)
                    }
                },
                enabled = isValid,
                isLoading = viewModel.isLoading
            )
            
            // Forgot password / Sign up hint
            Spacer(modifier = Modifier.height(12.dp))
            
            if (!isSignUp) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "New here?",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textSecondary
                    )
                    TextButton(onClick = { isSignUp = true }) {
                        Text(
                            text = "Create an account",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MomentTheme.colors.primary
                        )
                    }
                }
                
                TextButton(onClick = { viewModel.resetPassword(email) }) {
                    Text(
                        text = "Forgot password?",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MomentTheme.colors.textTertiary
                    )
                }
            }
        }
    }
}

@Composable
private fun TabButton(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    TextButton(
        onClick = onClick,
        modifier = modifier
            .padding(Spacing.xxs)
            .clip(RoundedCornerShape(CornerRadius.small))
            .background(
                if (isSelected) MomentTheme.colors.cardBackground
                else Color.Transparent
            )
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            color = if (isSelected) MomentTheme.colors.textPrimary 
                   else MomentTheme.colors.textSecondary
        )
    }
}

@Composable
private fun GoogleSignInButton(
    onClick: () -> Unit,
    isLoading: Boolean = false
) {
    Button(
        onClick = onClick,
        enabled = !isLoading,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MomentTheme.colors.primary,
            contentColor = Color.White
        ),
        shape = RoundedCornerShape(CornerRadius.medium)
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                color = Color.White,
                strokeWidth = 2.dp
            )
        } else {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_google),
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = Color.Unspecified
                )
                Spacer(modifier = Modifier.width(Spacing.sm))
                Text(
                    text = "Continue with Google",
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}

private suspend fun signInWithGoogle(context: Context, viewModel: AppViewModel) {
    try {
        val credentialManager = CredentialManager.create(context)
        
        // Get the web client ID from Firebase
        val options = FirebaseApp.getInstance().options
        val webClientId = options.apiKey
        
        // For Google Sign-In with Supabase, use the Google Cloud Web Client ID
        // This should match what's configured in Firebase/Supabase
        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(getGoogleWebClientId(context))
            .build()
        
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()
        
        val result = credentialManager.getCredential(
            request = request,
            context = context
        )
        
        handleSignInResult(result, viewModel)
        
    } catch (e: GetCredentialCancellationException) {
        // User cancelled, don't show error
        Log.d("AuthScreen", "Google Sign-In cancelled")
    } catch (e: GetCredentialException) {
        Log.e("AuthScreen", "Google Sign-In failed", e)
        viewModel.setError("Google Sign-In failed: ${e.message}")
    } catch (e: Exception) {
        Log.e("AuthScreen", "Unexpected error", e)
        viewModel.setError("Sign-in error: ${e.message}")
    }
}

private fun handleSignInResult(result: GetCredentialResponse, viewModel: AppViewModel) {
    val credential = result.credential
    
    when (credential) {
        is CustomCredential -> {
            if (credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
                val idToken = googleIdTokenCredential.idToken
                val displayName = googleIdTokenCredential.displayName
                
                viewModel.signInWithGoogle(idToken, null, displayName)
            }
        }
    }
}

private fun getGoogleWebClientId(context: Context): String {
    // The Web Client ID from Google Cloud Console / Firebase
    // This is the OAuth 2.0 Web Client ID, not the Android Client ID
    return context.getString(R.string.default_web_client_id)
}
