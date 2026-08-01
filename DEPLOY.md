# CarRent Manager – Deployment

This app runs on **Android**, **iOS**, **Windows** and **macOS** from a single codebase. Use the commands below to run and build for each platform.

---

## Prerequisites

- **Flutter SDK** installed and on your PATH ([flutter.dev](https://flutter.dev))
- **Windows**: Visual Studio 2022 with “Desktop development with C++” workload
- **macOS**: **Apple Mac** with Xcode

---

## Run (development)

| Platform   | Command |
|-----------|---------|
| **Windows** | `flutter run -d windows --release` (use `--release` to avoid Debug CRT linker issues) |
| **macOS**   | On a Mac: `flutter run -d macos` |

List devices: `flutter devices`

**Hot reload** (while the app is running): press **`r`** in the terminal for hot reload, **`R`** for hot restart. No need to stop and rebuild unless you change native code or `pubspec.yaml`.

---

## Build for release / delivery

| Platform   | Command | Output |
|-----------|---------|--------|
| **Windows** | `flutter build windows --release` | `build\windows\x64\runner\Release\` (folder with .exe) |
| **macOS**   | On a Mac: `flutter build macos --release` | `.app` in `build\macos\Build\Products\Release\` |

---

## Platform notes

- **Windows**: SQLite uses `sqflite_common_ffi` (initialized in `main.dart`). Use `--release` to avoid Debug build linker errors.
- **macOS**: SQLite uses the default `sqflite` (no FFI). Notifications require permission in System Settings.
- **OCR** (CIN / license scan): Uses each platform's built-in engine — ML Kit on Android, Apple Vision on iOS/macOS, WinRT OCR on Windows. Runs on-device with no server and no network.

---

## One-time setup per platform

- **macOS (Mac)**: Open `macos/Runner.xcworkspace` in Xcode, select team, enable signing if needed.

After these steps, the same codebase can be run and built on **Windows** and **macOS** as needed.
