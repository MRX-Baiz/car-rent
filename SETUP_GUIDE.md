# Build & Deployment Guide

CarRent Manager builds to a **single self-contained app** on every platform. There is no OCR server to install, launch or bundle — text recognition uses each operating system's built-in engine and runs entirely offline.

| Platform | OCR engine used | Minimum OS |
|---|---|---|
| Android | Google ML Kit | Android 5.0 (SDK 21) |
| iOS | Apple Vision | iOS 13 |
| macOS | Apple Vision | macOS 10.15 |
| Windows | WinRT OCR | Windows 10 |

## 1. Build

Run on the matching platform — desktop apps cannot be cross-compiled.

```bash
flutter build macos --release      # -> build/macos/Build/Products/Release/car_rent_manager.app
flutter build windows --release    # -> build\windows\x64\runner\Release\
flutter build apk --release        # -> build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release        # -> requires Xcode signing
```

## 2. Deploy

- **Windows**: copy the entire `Release` folder to the target PC and double-click `car_rent_manager.exe`.
- **macOS**: copy `car_rent_manager.app` to `/Applications`.
- **Android**: install the `.apk` directly, or ship an app bundle via `flutter build appbundle`.
- **iOS**: distribute through TestFlight or the App Store.

No Python, no Flutter SDK and no network connection are needed on the target machine.

## 3. Licensing

Each installation is bound to its hardware ID. To activate a machine:

1. Launch the app — the license screen shows that device's ID.
2. Generate a signed license for it:
   ```bash
   dart run scripts/license_generator.dart
   ```
   Choose option **2**, then enter the customer name, expiry date and the device ID.
3. Paste the generated key into the app's license screen.

`private_key.pem` signs every license — keep it secret and never commit it. Option **1** regenerates the keypair and invalidates all existing licenses, so only use it when starting fresh (and update the embedded key in `lib/core/license/asymmetric_crypto_helper.dart` to match).
