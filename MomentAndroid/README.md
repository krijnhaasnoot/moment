# Moment Android

Native Android app for Moment - a fertility tracking app for couples.

## Requirements

- Android Studio Hedgehog (2023.1.1) or newer
- JDK 17
- Android SDK 34
- Kotlin 1.9.22

## Setup

### 1. Supabase Configuration

De Supabase configuratie is al ingesteld in `app/build.gradle.kts` - dezelfde backend als de iOS app.

### 2. Build and Run

1. Open the project in Android Studio
2. Sync Gradle files
3. Run on emulator or device

## Project Structure

```
app/src/main/java/com/moment/app/
├── MomentApplication.kt      # Application class
├── MainActivity.kt           # Main activity
├── data/
│   └── model/
│       └── Models.kt         # Data models
├── service/
│   └── SupabaseService.kt    # Supabase API client
├── viewmodel/
│   └── AppViewModel.kt       # Main ViewModel
└── ui/
    ├── MomentApp.kt          # Main composable
    ├── theme/
    │   ├── Color.kt          # Color definitions
    │   ├── Theme.kt          # Theme setup
    │   ├── Type.kt           # Typography
    │   └── Components.kt     # Reusable components
    ├── auth/
    │   └── AuthScreen.kt     # Authentication
    ├── onboarding/
    │   ├── OnboardingScreen.kt
    │   └── SetupCycleScreen.kt
    ├── home/
    │   └── HomeScreen.kt     # Today view
    ├── calendar/
    │   └── CalendarScreen.kt # Calendar view
    └── settings/
        └── SettingsScreen.kt # Settings
```

## Features

- [x] Email authentication
- [x] Google Sign-In (TODO: implement)
- [x] Role-based onboarding (woman/partner)
- [x] Couple connection via invite codes
- [x] Cycle tracking
- [x] Fertility calendar
- [x] LH test logging
- [x] Intimacy logging
- [x] Profile photo upload
- [ ] Push notifications
- [ ] Offline support

## Tech Stack

- **UI**: Jetpack Compose with Material 3
- **Architecture**: MVVM with ViewModel
- **Backend**: Supabase (Auth, Database, Storage)
- **Networking**: Ktor Client
- **Serialization**: Kotlinx Serialization
- **Image Loading**: Coil
- **Date/Time**: kotlinx-datetime

## Shared Backend

This app shares the same Supabase backend as the iOS app. All data models, RLS policies, and database schema are compatible.

## Building for Release

1. Create a keystore for signing
2. Configure signing in `app/build.gradle.kts`
3. Build release APK:

```bash
./gradlew assembleRelease
```

Or build App Bundle for Play Store:

```bash
./gradlew bundleRelease
```
