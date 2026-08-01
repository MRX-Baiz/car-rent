# 🚀 CarRent Manager - Complete Release Build Guide

This guide provides step-by-step instructions for building and deploying **CarRent Manager** on **macOS** and **Windows**.

---

## 📋 Table of Contents
- [Prerequisites](#prerequisites)
- [macOS Release Build](#macos-release-build)
- [Windows Release Build](#windows-release-build)
- [Debugging Released Apps](#debugging-released-apps)
- [Distribution](#distribution)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Common Requirements
- **Flutter SDK** (3.0.0 or higher) installed and added to PATH
- **Git** installed
- **Python 3.9+** (for OCR server packaging)

### macOS Requirements
- **macOS** computer (required for building macOS apps)
- **Xcode** (latest version from App Store)
- **Xcode Command Line Tools**: `xcode-select --install`
- **CocoaPods**: `sudo gem install cocoapods`

### Windows Requirements
- **Windows 10/11** computer
- **Visual Studio 2022** with "Desktop development with C++" workload
- **Python** installed from python.org or Microsoft Store

---

## 🍎 macOS Release Build

### Step 1: Verify Flutter Setup
```bash
flutter doctor -v
```
Ensure macOS toolchain and Xcode are properly configured.

### Step 2: Clean Previous Builds
```bash
flutter clean
flutter pub get
```

### Step 3: Configure Xcode Signing (First Time Only)

1. Open the Xcode workspace:
   ```bash
   open macos/Runner.xcworkspace
   ```

2. In Xcode:
   - Select **Runner** in the left sidebar
   - Go to **Signing & Capabilities** tab
   - Select your **Team** (Apple Developer account or personal team)
   - Ensure **"Automatically manage signing"** is checked
   - Bundle Identifier should be: `com.yourcompany.carRentManager` (you can change this)

3. Close Xcode

### Step 4: Build Release (Manual Method)
```bash
flutter build macos --release
```

**Output location:**
```
build/macos/Build/Products/Release/car_rent_manager.app
```

### Step 5: Build with OCR Server (Automated Script)

This script builds the Flutter app AND packages the OCR server together:

```bash
chmod +x package_macos.sh
./package_macos.sh
```

**Output location:**
```
build/macos/Build/Products/Release/
├── car_rent_manager.app
└── ocr_server/
    └── server/
```

### Step 6: Test the Release Build
```bash
open build/macos/Build/Products/Release/car_rent_manager.app
```

### Step 7: Create Distributable Package

**Option A: Simple ZIP**
```bash
cd build/macos/Build/Products/Release
zip -r CarRentManager-macOS.zip car_rent_manager.app ocr_server/
```

**Option B: DMG Installer (Recommended)**
```bash
# Install create-dmg if not already installed
brew install create-dmg

# Create DMG
create-dmg \
  --volname "CarRent Manager" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 185 \
  "CarRentManager-Installer.dmg" \
  "build/macos/Build/Products/Release/car_rent_manager.app"
```

---

## 🪟 Windows Release Build

### Step 1: Verify Flutter Setup
```cmd
flutter doctor -v
```
Ensure Windows toolchain and Visual Studio are properly configured.

### Step 2: Clean Previous Builds
```cmd
flutter clean
flutter pub get
```

### Step 3: Build Release (Manual Method)
```cmd
flutter build windows --release
```

**Output location:**
```
build\windows\x64\runner\Release\
├── car_rent_manager.exe
├── flutter_windows.dll
├── data\
└── (other DLLs)
```

### Step 4: Build with OCR Server (Automated Script)

This script builds the Flutter app AND packages the OCR server together:

```cmd
package_windows.bat
```

**Output location:**
```
build\windows\x64\runner\Release\
├── car_rent_manager.exe
├── flutter_windows.dll
├── data\
└── ocr_server\
    └── server\
```

### Step 5: Test the Release Build
```cmd
cd build\windows\x64\runner\Release
car_rent_manager.exe
```

### Step 6: Create Distributable Package

**Option A: Simple ZIP**
```cmd
cd build\windows\x64\runner
powershell Compress-Archive -Path Release\* -DestinationPath CarRentManager-Windows.zip
```

**Option B: Installer (Recommended)**

Use **Inno Setup** to create a professional installer:

1. Download and install [Inno Setup](https://jrsoftware.org/isdl.php)

2. Create `installer.iss` file in your project root:

```iss
[Setup]
AppName=CarRent Manager
AppVersion=1.0.0
DefaultDirName={autopf}\CarRentManager
DefaultGroupName=CarRent Manager
OutputDir=installers
OutputBaseFilename=CarRentManager-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\CarRent Manager"; Filename: "{app}\car_rent_manager.exe"
Name: "{autodesktop}\CarRent Manager"; Filename: "{app}\car_rent_manager.exe"

[Run]
Filename: "{app}\car_rent_manager.exe"; Description: "Launch CarRent Manager"; Flags: nowait postinstall skipifsilent
```

3. Compile the installer:
   - Right-click `installer.iss` → **Compile**
   - Or run: `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss`

---

## 🐛 Debugging Released Apps

### Crash Logs Location

The app automatically creates crash logs when errors occur:

**macOS:**
```bash
# Logs are saved next to the .app
~/Library/Containers/com.yourcompany.carRentManager/Data/crash_log.txt

# Or in the app's directory
build/macos/Build/Products/Release/crash_log.txt
```

**Windows:**
```cmd
# Logs are saved in the same folder as the .exe
build\windows\x64\runner\Release\crash_log.txt

# Or after installation
C:\Program Files\CarRentManager\crash_log.txt
```

### Viewing Crash Logs

**macOS:**
```bash
cat crash_log.txt
# Or
open -a TextEdit crash_log.txt
```

**Windows:**
```cmd
type crash_log.txt
# Or
notepad crash_log.txt
```

### Enable Additional Logging

To add more detailed logging to your release build, modify `lib/main.dart`:

```dart
Future<void> main() async {
  // Add this for detailed logging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logError('Flutter Error', details.exception, details.stack);
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // ... rest of your code
    
  } catch (e, stack) {
    _logError('Main Crash', e, stack);
    rethrow;
  }
}

void _logError(String title, dynamic error, StackTrace? stack) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '''
[$timestamp] $title
Error: $error
Stack Trace:
$stack
${'=' * 80}
''';
  
  try {
    final logFile = File('crash_log.txt');
    logFile.writeAsStringSync(
      logMessage,
      mode: FileMode.append,
    );
  } catch (_) {}
}
```

### Testing Release Builds Locally

**macOS:**
```bash
# Run release build directly
flutter run -d macos --release

# Or run the built .app
open build/macos/Build/Products/Release/car_rent_manager.app
```

**Windows:**
```cmd
# Run release build directly
flutter run -d windows --release

# Or run the built .exe
build\windows\x64\runner\Release\car_rent_manager.exe
```

### Console Output in Release

To see console output from release builds:

**macOS:**
```bash
# Run from terminal to see logs
build/macos/Build/Products/Release/car_rent_manager.app/Contents/MacOS/car_rent_manager
```

**Windows:**
```cmd
# Run from command prompt to see logs
build\windows\x64\runner\Release\car_rent_manager.exe
```

---

## 📦 Distribution

### macOS Distribution

**For Internal Use (No Code Signing):**
- Share the `.app` file or DMG
- Users may need to right-click → Open (first time only) to bypass Gatekeeper

**For Public Distribution:**
1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Code sign the app:
   ```bash
   codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" \
     build/macos/Build/Products/Release/car_rent_manager.app
   ```
3. Notarize with Apple (required for macOS 10.15+)

### Windows Distribution

**For Internal Use:**
- Share the ZIP or installer
- Windows Defender may show a warning (normal for unsigned apps)

**For Public Distribution:**
1. Get a code signing certificate (from DigiCert, Sectigo, etc.)
2. Sign the executable:
   ```cmd
   signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com car_rent_manager.exe
   ```

---

## 🔧 Troubleshooting

### macOS Issues

**"App is damaged and can't be opened"**
```bash
xattr -cr build/macos/Build/Products/Release/car_rent_manager.app
```

**Xcode signing errors**
- Open `macos/Runner.xcworkspace` in Xcode
- Clean build folder: Product → Clean Build Folder
- Verify signing settings

**CocoaPods issues**
```bash
cd macos
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### Windows Issues

**Missing DLLs**
- Ensure all files in `Release` folder are included
- Install Visual C++ Redistributable on target machine

**Build fails with linker errors**
- Always use `--release` flag
- Ensure Visual Studio 2022 is properly installed

**OCR Server not found**
- Verify `ocr_server` folder is in the same directory as the .exe
- Check Python dependencies are packaged correctly

### Common Issues (Both Platforms)

**Database errors**
- Delete old database: `app_data.db`
- App will recreate on next launch

**License validation fails**
- Check `private_key.pem` and `public_key.pem` are in project root
- Verify license generation script

**OCR not working**
- Ensure OCR server is packaged correctly
- Check if Python dependencies are included
- Test OCR server independently

---

## 📝 Build Checklist

### Before Building

- [ ] Update version in `pubspec.yaml`
- [ ] Test app in debug mode
- [ ] Update app icon (if needed)
- [ ] Update app name in `Info.plist` (macOS) or `CMakeLists.txt` (Windows)
- [ ] Verify license keys are correct
- [ ] Test database migrations

### After Building

- [ ] Test release build on clean machine
- [ ] Verify OCR functionality
- [ ] Test license activation
- [ ] Check crash logs are created
- [ ] Test all major features
- [ ] Create backup of build

### Distribution

- [ ] Create installer/DMG
- [ ] Write release notes
- [ ] Test installation on target machines
- [ ] Provide user documentation
- [ ] Set up support channel

---

## 🎯 Quick Reference

### Build Commands

| Platform | Command | Output |
|----------|---------|--------|
| macOS (app only) | `flutter build macos --release` | `build/macos/Build/Products/Release/*.app` |
| macOS (with OCR) | `./package_macos.sh` | `build/macos/Build/Products/Release/` |
| Windows (app only) | `flutter build windows --release` | `build\windows\x64\runner\Release\` |
| Windows (with OCR) | `package_windows.bat` | `build\windows\x64\runner\Release\` |

### Log Locations

| Platform | Location |
|----------|----------|
| macOS | `crash_log.txt` (next to .app) |
| Windows | `crash_log.txt` (same folder as .exe) |

---

## 📞 Support

For issues or questions:
1. Check crash logs first
2. Review this guide's troubleshooting section
3. Run `flutter doctor -v` and check for issues
4. Test in debug mode to get more detailed errors

---

**Last Updated:** April 2026
**App Version:** 1.0.0
