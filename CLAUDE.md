# CarRent Manager — project guide

Vehicle rental management app for a single-operator agency: vehicles, clients,
contracts, payments, PDF contract generation, on-device OCR of Moroccan CIN /
driving-licence documents, and local notifications for return deadlines.
Flutter, one codebase, Android first — other platforms build but are not the
current focus.

**If you are Claude Code opening this project fresh**: read this whole file
before touching code. It records decisions that were reached by trial and
error, including two approaches that looked reasonable and did not work. If
you're about to re-derive one of them, the "why" is below — read it first.

---

## 1. The signing key

`private_key.pem` (RSA-4096) signs every licence key and every PIN-reset
token. `.gitignore` still lists `*.pem` — that line is what keeps a routine
`git add .` from ever picking it up by accident — but it **is** committed to
this repo (force-added, deliberately, so it travels with `git clone` instead
of needing an out-of-band transfer). The app embeds the matching **public**
key separately (`lib/core/license/asymmetric_crypto_helper.dart`), which can
verify but not sign.

This is a considered trade-off, not an oversight: it only holds up as long as
this repository stays private. If it is ever made public, forked to a public
remote, or added as a dependency anywhere, **rotate the key immediately** —
regenerate the pair, update the embedded public key in
`asymmetric_crypto_helper.dart`, and every licence and reset token already
issued from the old key stops verifying (existing installs keep running;
issuing *new* licences/tokens for them needs the new key). Anyone who reaches
this repo can otherwise mint a valid licence or PIN-reset token for any
device without contacting the vendor at all.

You don't need the key to build, run, or test the app day to day — the tests
that touch signing generate their own throwaway RSA keypair
(`test/pin_recovery_test.dart`, `test/license_crypto_test.dart`). It's only
read by `scripts/generate_license.sh` and `scripts/generate_reset_token.sh`.

---

## 2. Architecture decisions and why

These are the parts of the app that don't look the way a first draft would,
because the first draft was tried and something broke.

### Auth is a local PIN, not user accounts

One operator, one phone. The old build had a username/password screen that
authenticated nothing — any non-empty pair generated a session token; no
credential was ever compared. It was replaced with a 6-digit PIN (PBKDF2-
HMAC-SHA256, random salt, `lib/core/security/pin_hasher.dart`) plus optional
biometric unlock, enforced by a `redirect` in `lib/app.dart` that every data
route goes through (`lockRedirect`, tested for all 13 screens in
`test/lock_guard_test.dart`).

**Don't propose user accounts / roles unless the user says staff will share
one device** — that fork was offered explicitly and declined. The real
security boundary is the device-bound licence key, not the PIN; the PIN
protects data if the phone is lost or handed over, nothing more. A 6-digit
PIN is a million combinations — the lockout ladder (5 free attempts, then
30s → 1m → 5m → 15m → 30m, `AuthRepository._lockoutFor`) is what makes
guessing impractical, not the PBKDF2 iteration count.

**PIN recovery** is two-tier, both built on `lib/core/security/`:
- A 12-digit recovery code, shown once at PIN creation
  (`recovery_code_view.dart`), hash stored the same way as the PIN. Single
  use — redeeming it or regenerating it invalidates the old one.
- A vendor-issued reset token (`pin_reset_token.dart`), signed with the same
  private key as a licence, bound to one device id, carrying a strictly
  increasing serial (replay protection) and a short expiry (default 24h, so
  a token left in a chat thread goes stale on its own even if never used).
  Minted with `scripts/generate_reset_token.sh`.

Both clear the PIN only — clients, contracts, payments, scanned documents are
untouched. This was a deliberate call: it's a recovery, not a security
incident.

### Hardware back button: `BackButtonDispatcher`, not `PopScope` or `onExit`

Two earlier approaches were tried and both failed for non-obvious reasons —
don't reintroduce either.

- **`PopScope`** is never consulted here. go_router 13's
  `GoRouterDelegate.popRoute()` drops the navigator whenever `canPop()` is
  false — which it is, on a bottom-nav tab with nothing pushed on top — and
  `maybePop()` (the only thing that triggers `PopScope`) is skipped entirely.
- **`GoRoute.onExit`** looked like the right hook but fires on *every* route
  exit, not just a hardware back press — including an ordinary `go()` to
  another tab. Returning `false` from it to keep the app alive therefore also
  vetoed normal tab switching, and navigating from inside the callback
  re-entered the router and deadlocked it.

The fix (`lib/core/navigation/tab_back_button_dispatcher.dart`) sits above the
router as a custom `BackButtonDispatcher` and sees the press before it becomes
a pop, so neither failure mode applies. See `test/back_navigation_test.dart`.

### Attachments live in `MediaStore`, not wherever the picker left them

`image_picker` / `file_picker` hand back a copy in the OS **cache**, which
Android reclaims at will. Saving that path straight into the database (the
original bug) meant a permis or CIN photo — or the company logo/signature
used in generated contract PDFs — could vanish by the next app launch with no
error anywhere.

`lib/core/storage/media_store.dart` copies every attachment into permanent
app storage on save, and the database stores a **file name**, not an absolute
path — the app's storage directory is not guaranteed stable (iOS relocates it
on every update). `MediaStore.instance.resolveSync()` degrades to a
placeholder icon rather than a crash if a file from before this fix is
already gone. See `test/media_store_test.dart`.

Vehicle photos are the one exception: they're stored as a BLOB in the
database directly, so they were never affected. Not migrated to `MediaStore`
because they work as-is; flagged here in case it becomes worth doing.

### Notifications: local only, and permission has to be *asked for*

`lib/core/notifications/notification_service.dart`. A few non-obvious things
that cost real debugging time:

- **Exact alarms need a separate, explicit grant** on Android 12+
  (`SCHEDULE_EXACT_ALARM` in the manifest, `requestExactAlarmsPermission()` at
  runtime). Without it Android silently downgrades to an inexact alarm and
  Doze holds it until the device next wakes — a reminder set for 5 minutes
  out can arrive whenever the phone is next picked up, with **no error
  anywhere**. This is asked for when a contract is saved (the moment
  reminders are obviously wanted), not at launch. `Settings → Rappels` has a
  diagnostics panel (`NotificationDiagnostics`) that shows whether it's
  granted and a button to fix it — use it first if a reminder doesn't arrive.
- The Android manifest needs three `<receiver>` entries
  (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`,
  `ActionBroadcastReceiver`) or a scheduled alarm has nothing to deliver to.
  Already in `android/app/src/main/AndroidManifest.xml` — don't remove them.
- Timezone was originally pinned to UTC, which kept one-shot reminders
  correct but drifted the *daily* overdue repeat by the local UTC offset
  every day. Now read from the device via `flutter_timezone`.
- The overdue-vehicle digest used to re-fire every time the app returned to
  the foreground — including the return caused by tapping the notification
  itself, which made it feel like it never stopped. It's now keyed by a
  signature of which contracts are overdue (`digestSignature`) and only
  alerts when that set actually changes; opening the app clears it instead.
- A notification tap can't navigate directly if the app is locked — the PIN
  guard would just bounce it to `/lock` and the destination would be lost.
  `pendingNotificationRoute` (a `ValueNotifier<String?>`) parks it, and
  `CarRentApp` replays it once `lockSignal` reports `unlocked`.

**Known gap, not yet verified**: the exact-alarm permission fix is in and the
diagnostics panel is built, but end-to-end delivery on a real device with the
full 5-minute-contract test hasn't been confirmed clean yet. If reminders are
still late or missing after checking the diagnostics panel, the next suspect
is OEM battery optimisation (Xiaomi/Huawei/Oppo/Samsung all kill background
alarms for apps not explicitly whitelisted, independent of any Android
permission) — that's `Réglages → Applications → CarRent Manager → Batterie →
Sans restriction`, not something fixable from app code.

### Licensing: RSA-4096, device-bound, offline

`lib/core/license/`. A licence is a base64-wrapped `{data, signature}`
envelope — name, expiry, device id — signed with RSA-4096 PSS/SHA-256 and
verified against the embedded public key. No server: `verifyLicense` runs
entirely on-device. `validateRuntime()` additionally detects clock rollback
(a hash of the last-run timestamp, so winding the system clock back to defeat
an expiry is caught). `scripts/generate_license.sh` mints one from the
private key; the app's licence screen shows the device id you paste in there.

### OCR is on-device, no server

An earlier iteration ran a separate Python/EasyOCR server alongside the app.
It's gone — OCR now runs through platform-native engines
(`flutter_ocr_native`: ML Kit on Android, Apple Vision on macOS) so the app
ships as a single package with nothing to deploy separately.
`lib/core/ocr/ocr_service.dart` has Moroccan-document-specific parsing
(French/Arabic name handling, permis/CIN field extraction) validated against
real scanned documents in `test/ocr_parsing_test.dart` — those tests use
verbatim engine output, not synthetic strings, because the actual failure
modes only showed up on real OCR noise.

---

## 3. Tech stack

| | |
|---|---|
| Flutter | 3.44.8 (stable channel) |
| Dart | 3.12.2 |
| State management | Riverpod 2.x (`flutter_riverpod`) |
| Navigation | `go_router` ^13.0.0 |
| Database | `sqflite` (mobile) / `sqflite_common_ffi` (Windows, Linux) |
| Notifications | `flutter_local_notifications` ^17 + `timezone` + `flutter_timezone` |
| Crypto | `fast_rsa` (licence/reset-token signing), `crypto` (PBKDF2/SHA-256) |
| Biometrics | `local_auth` ^3 |
| PDF | `pdf` + `printing` |
| OCR | `flutter_ocr_native` 0.2.1 — **pinned**, see comment in `pubspec.yaml` |

Full list in `pubspec.yaml`.

---

## 4. Setting up on a new machine (Windows)

1. **Install Flutter.** Match the version above if possible
   (`flutter --version` after install; `flutter upgrade` if it's behind).
   Windows install: unzip the SDK somewhere without spaces in the path, add
   `<flutter>\bin` to `PATH`.
2. **Enable Windows Developer Mode.** Settings → Privacy & Security →
   For developers → Developer Mode → On. Flutter's build needs symlink
   support; without this, `flutter run` fails partway with a permissions
   error that doesn't obviously point at this setting.
3. **Install Android Studio**, then through its SDK Manager:
   - An Android SDK Platform (34 or 35 is fine)
   - A build-tools version matching it
   - **NDK 28.2.13676358** specifically — this project's
     `android/app/build.gradle.kts` takes `ndkVersion` from
     `flutter.ndkVersion`, which resolves to that version for this Flutter
     release. A different/missing NDK is the single most common Android build
     failure on a fresh machine.
   - JDK 17 (Android Studio bundles one; point `JAVA_HOME` at it if
     `flutter doctor` complains).
4. **Set environment variables**: `ANDROID_HOME` (SDK path) and `JAVA_HOME`.
5. **`git clone`** this repo, then from the project root:
   ```
   flutter pub get
   flutter doctor
   ```
   Resolve anything `flutter doctor` flags before going further.
6. **Verify the checkout is healthy**:
   ```
   flutter analyze      # expect 0 errors
   flutter test         # expect 126 passing
   ```
7. **Run it**:
   ```
   flutter run -d windows           # desktop
   flutter run -d <android-device>  # phone, USB debugging on
   ```

---

## 5. Repository

- `origin` → `github.com/MRX-Baiz/car-rent` — the active repo, push here.
- An older repo, `V2-car-renting`, exists and is kept as a remote named
  `v2-old` in the original development machine for history; it is not where
  new work goes.
- The commit history was deliberately restructured once (see the first dozen
  commits) into one logical change per commit with a "why" in the message,
  because the working history up to that point was one flat diff. Keep doing
  that going forward rather than reverting to giant commits — it's what makes
  `git log` useful on this project.

---

## 6. Project structure

```
lib/
  core/
    database/          SQLite schema + migrations (DatabaseHelper)
    document/           text extraction for imported PDFs/docx
    license/            RSA-signed licence verification (LicenseManager)
    navigation/          TabBackButtonDispatcher — read §2 before touching
    notifications/       NotificationService, preferences, digest logic
    ocr/                 on-device OCR + Moroccan-document field parsing
    pdf/                 contract PDF generation
    security/            PinHasher, RecoveryCode, PinResetToken
    storage/              MediaStore — read §2 before touching
  data/
    models/              plain data classes (ClientModel, ContractModel, …)
    repositories/        DB/settings access, AuthRepository
  presentation/
    providers/           Riverpod providers (one per domain area)
    screens/              one folder per feature area
      lock/                PIN setup, lock screen, recovery
    widgets/              shared widgets (pin_pad, document_viewer, …)
  app.dart                GoRouter config + the lock redirect
  main.dart               entry point, service init order matters here

scripts/
  generate_license.sh       mint a licence key (needs private_key.pem)
  generate_reset_token.sh   mint a PIN-reset token (needs private_key.pem)
  make_icon_assets.py       launcher icon from source art
  make_notification_icon.py status-bar icon (monochrome silhouette)

test/                     126 tests; see §7
```

---

## 7. Testing

```
flutter analyze     # must be 0 errors before committing
flutter test         # 126 tests as of this writing
```

Every security-relevant piece has a test that fails without the fix it's
guarding, not just a happy-path check:

- `pin_hasher_test.dart` — PBKDF2 verified against published RFC test vectors.
- `pin_recovery_test.dart` — includes a fixture token actually minted by
  `generate_reset_token.sh` with the real private key, so the bash JSON
  encoding and the Dart verifier are proven to agree byte-for-byte, not just
  "should probably match."
- `lock_guard_test.dart` — every one of the 13 data routes, checked against
  all four lock states.
- `media_store_test.dart` — reproduces the original bug (picker cache wiped
  after save) and confirms it fails without the fix.
- `back_navigation_test.dart` — a regression guard is in there specifically
  because the `onExit` approach silently broke ordinary tab switching, not
  just the back button; don't remove that test when touching navigation.
- `notification_test.dart` — the digest de-duplication logic (order-
  independent, changes-only) that stops the repeat-alert bug from §2.

If you fix a bug, add the test that would have caught it before writing the
fix — that's the standard the existing suite was held to.

---

## 8. Known gaps / open work

Roughly in the order they'd bite someone:

1. **Notification delivery on real hardware isn't fully confirmed yet.** The
   exact-alarm permission fix and diagnostics panel are in; the 5-minute
   test-contract scenario needs a clean run to close this out. See §2.
2. **No export/import feature.** Android's auto-backup is on by default but
   caps at 25MB total per app — easily exceeded once client documents
   accumulate, and it fails *silently* (no error to the user or developer).
   It's a reasonable safety net for a small install, not something to promise
   customers as their migration path between devices. A real export-to-file /
   import-from-file flow was discussed but not started.
3. **iOS / Windows / macOS are buildable but not the focus.** Android is
   where the polish has gone (launcher icon, notification icon, back-button
   handling, biometric host activity). Expect rough edges elsewhere.
4. **Vehicle photos stay as a database BLOB**, unlike every other attachment
   (which goes through `MediaStore`). Works fine; flagged in §2 as the one
   inconsistency if someone goes looking for one.
5. **Release APK signing uses the debug keystore**
   (`android/app/build.gradle.kts`, has a `// TODO`). Fine for direct
   install/testing; needs a real signing config before any Play Store
   submission, and switching keys later means old installs can't be updated
   in place by the new key without users reinstalling.

---

## 9. Working conventions

- Write no comments by default; when you do, explain *why*, not *what* — the
  existing code leans on this heavily (see any file in `core/`) and it's
  intentional.
- UI strings are French (the target users are Moroccan rental agencies); some
  error messages are trilingual (French/Arabic/English) where they were
  already that way — don't remove the extra languages, but don't feel
  obligated to add them to new strings either.
- Prefer fixing the root cause over adding a fallback/try-catch around it —
  several of the bugs in §2 were originally masked by exactly that kind of
  patch, which is why they took two rounds to actually fix.
- Don't commit without being asked to. Don't push without being asked to.
