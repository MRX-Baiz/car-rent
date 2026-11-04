# Building

CarRent Manager builds to a single self-contained app on each platform. Text
recognition uses the operating system's own engine, so there is nothing to
install or run alongside it.

| Platform | OCR engine | Minimum OS |
|---|---|---|
| Android | Google ML Kit | Android 5.0 (SDK 21) |
| iOS / macOS | Apple Vision | iOS 13 / macOS 10.15 |
| Windows | WinRT OCR | Windows 10 |

## Prerequisites

- Flutter 3.44 (stable); check with `flutter doctor`.
- Android: Android SDK, JDK 17, and the NDK version Flutter selects
  (`flutter.ndkVersion`; currently 28.2.13676358).
- Windows: Visual Studio 2022 with the "Desktop development with C++"
  workload, and Developer Mode enabled for symlink support.
- macOS / iOS: Xcode and CocoaPods.

## Run

```bash
flutter pub get
flutter run -d <device>     # see `flutter devices`
```

On Windows use `flutter run -d windows --release` to avoid debug CRT linker
errors.

## Release builds

Desktop apps cannot be cross-compiled; build on the target OS.

```bash
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release
flutter build macos --release
flutter build windows --release
```

The Android release build is currently signed with the debug keystore. Add a
real signing configuration (and keep it out of the repository: `key.properties`
and `*.jks` are git-ignored) before publishing to the Play Store.

## Tests

```bash
flutter analyze
flutter test
```
