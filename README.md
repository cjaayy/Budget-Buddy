# BudgetBuddy

BudgetBuddy is a Flutter Android app for daily budgeting, meal planning, gala/stroll planning, expense tracking, analytics, and local-first savings guidance.

## What It Includes

- Daily budget planner with animated summaries
- Smart meal suggestions for budget meals, healthy meals, and street food
- Gala / stroll planner with mood-based activity recommendations
- Expense tracker with edit, delete, and category filtering
- End-of-day analytics with pie, line, and breakdown charts
- Dark mode and light mode
- Local persistence with Hive and SharedPreferences
- PDF report export and local notifications
- Windows launcher script with build, run, and adb helpers

## Project Structure

- `lib/core` shared models, services, theme, state, and utilities
- `lib/features` feature screens for dashboard, budget, meals, gala, expenses, analytics, auth, onboarding, splash, and profile
- `android/` Android project configuration for package `com.budgetbuddy.app`
- `run_budgetbuddy.bat` Windows launcher and build helper

## Requirements

- Flutter SDK 3.3 or newer
- Dart 3.3 or newer
- Android Studio or Android SDK command-line tools
- A connected Android device or emulator

## Setup

1. Install Flutter and confirm `flutter --version` works.
2. From the project root, run `flutter pub get`.
3. Connect an Android device or start an emulator.
4. Run `flutter run` or use `run_budgetbuddy.bat`.

## Windows Launcher

Run `run_budgetbuddy.bat` from the project root to:

- launch the app on a connected Android device
- build APK or AAB outputs
- open the APK output folder
- uninstall the app from the device
- reconnect wireless ADB sessions
- print system specs and connected devices

## Notes

- The app uses local dummy data on first launch so the dashboard is immediately useful.
- If Flutter has not been installed on this machine yet, the source files are ready but the project cannot be executed until Flutter is available.
