# CarRent Manager

Vehicle rental management app (Flutter). Runs on **Android**, **iOS**, **Windows** and **macOS** from a single codebase.

## Features

- Vehicles, clients, contracts, payments
- License activation
- PDF contract generation and printing
- Local notifications (return reminders)
- Company settings
- On-device OCR scanning of CIN / driving licences (works offline, no server)

## Getting Started

1. Install [Flutter](https://flutter.dev).
2. Clone the project and run:
   ```bash
   flutter pub get
   ```
3. Run on your target device (see [DEPLOY.md](DEPLOY.md)):
   - **Windows**: `flutter run -d windows --release`
   - **macOS**: on a Mac, `flutter run -d macos`

4. **Hot reload** (while the app is running in the terminal):
   - Press **`r`** for hot reload (fast, keeps state).
   - Press **`R`** for hot restart (full restart, resets state).
   - No need to stop and rebuild unless you change native code or dependencies.

## Multi-Platform Deployment

See **[DEPLOY.md](DEPLOY.md)** for run and build commands for Windows/macOS and how to deliver the app.
