package com.moment.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.moment.app.ui.auth.AuthScreen
import com.moment.app.ui.home.HomeScreen
import com.moment.app.ui.onboarding.OnboardingScreen
import com.moment.app.ui.onboarding.SetupCycleScreen
import com.moment.app.ui.theme.MomentTheme
import com.moment.app.viewmodel.AppScreen
import com.moment.app.viewmodel.AppViewModel

@Composable
fun MomentApp(
    viewModel: AppViewModel = viewModel()
) {
    AnimatedContent(
        targetState = viewModel.currentScreen,
        transitionSpec = {
            fadeIn() togetherWith fadeOut()
        },
        label = "screen_transition"
    ) { screen ->
        when (screen) {
            AppScreen.LOADING -> LoadingScreen()
            AppScreen.AUTH -> AuthScreen(viewModel = viewModel)
            AppScreen.ONBOARDING -> OnboardingScreen(viewModel = viewModel)
            AppScreen.SETUP_CYCLE -> SetupCycleScreen(viewModel = viewModel)
            AppScreen.HOME -> HomeScreen(viewModel = viewModel)
        }
    }
}

@Composable
private fun LoadingScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            color = MomentTheme.colors.primary
        )
    }
}
