# CarRent Manager – Multi-Platform Deployment

This app runs on **Windows**, **Android**, **macOS**, and **iOS**. Use the commands below to run and build for each platform.

---

## Prerequisites

- **Flutter SDK** installed and on your PATH ([flutter.dev](https://flutter.dev))
- **Windows**: Visual Studio 2022 with “Desktop development with C++” workload
- **Android**: Android Studio + SDK; for device/emulator: USB debugging or AVD
- **macOS / iOS**: **Apple Mac** with Xcode (only Mac can build for macOS and iOS)

---

## Run (development)

| Platform   | Command |
|-----------|---------|
| **Windows** | `flutter run -d windows --release` (use `--release` to avoid Debug CRT linker issues) |
| **Android** | `flutter run -d android` or `flutter run -d <device_id>` (e.g. `emulator-5554`) |
| **macOS**   | On a Mac: `flutter run -d macos` |
| **iOS**     | On a Mac: `flutter run -d ios` (simulator or connected iPhone) |

List devices: `flutter devices`

---

## Build for release / delivery

| Platform   | Command | Output |
|-----------|---------|--------|
| **Windows** | `flutter build windows --release` | `build\windows\x64\runner\Release\` (folder with .exe) |
| **Android** | `flutter build apk --release` | `build\app\outputs\flutter-apk\app-release.apk` |
| **Android (App Bundle)** | `flutter build appbundle --release` | `build\app\outputs\bundle\release\app-release.aab` (for Play Store) |
| **macOS**   | On a Mac: `flutter build macos --release` | `.app` in `build\macos\Build\Products\Release\` |
| **iOS**     | On a Mac: `flutter build ios --release` then archive in Xcode | IPA for App Store / TestFlight |

---

## Platform notes

- **Windows**: SQLite uses `sqflite_common_ffi` (initialized in `main.dart`). Use `--release` to avoid Debug build linker errors.
- **Android / iOS / macOS**: SQLite uses the default `sqflite` (no FFI). Notifications are supported on all three.
- **iOS**: Notifications require proper capabilities in Xcode and user permission at runtime.
- **macOS**: Notifications require permission in System Preferences.
- **OCR** (CIN / license scan): Currently implemented on Android (ML Kit); on other platforms the app uses manual entry.

---

## One-time setup per platform

- **Android**: Accept licenses: `flutter doctor --android-licenses`
- **iOS (Mac)**: Open `ios/Runner.xcworkspace` in Xcode, select team, enable signing.
- **macOS (Mac)**: Open `macos/Runner.xcworkspace` in Xcode, select team, enable signing if needed.

After these steps, the same codebase can be run and built on **Windows**, **Android**, **macOS**, and **iOS** as needed.
