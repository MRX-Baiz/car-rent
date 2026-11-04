# CarRent Manager — project guide

Vehicle rental management app for a single-operator agency: vehicles, clients,
contracts, payments, PDF contract generation, on-device OCR of Moroccan CIN /
driving-licence documents, and local notifications for return deadlines.
Flutter, one codebase, Android first — other platforms build but are not the
current focus.

**If you are an AI assistant or a new contributor opening this project fresh**: read this whole file
before touching code. It records decisions that were reached by trial and
error, including two approaches that looked reasonable and did not work. If
you're about to re-derive one of them, the "why" is below — read it first.

---

## 1. The signing key

`private_key.pem` (RSA-4096) signs every licence key and every PIN-reset
token. It is **not in this repository** and must never be committed: `.gitignore`
excludes `*.pem` and the other key/keystore formats. It lives at
`~/.carrent/private_key.pem` (or wherever `$PRIVATE_KEY` points), and
`scripts/generate_license.sh` / `scripts/generate_reset_token.sh` read it from
there. The app embeds the matching **public** key
(`lib/core/license/asymmetric_crypto_helper.dart`), which can verify but not
sign. See `docs/licensing.md`.

You don't need the key to build, run, or test the app — the tests that touch
signing generate their own throwaway RSA keypair (`test/pin_recovery_test.dart`,
`test/license_crypto_test.dart`).

If the key is ever exposed, rotate it: regenerate the pair, update the embedded
public key, and re-issue licences. Existing installs keep running; issuing new
licences/tokens for them needs the new key.

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
- Android daily overdue alarms must preserve their first date (the day after
  the return deadline). `DateTimeComponents.time` ignores that date and can
  fire today, even when tomorrow was passed. `AndroidDailyReminder` uses the
  native `scheduledNotificationRepeatFrequency: 0` (Daily) channel field in
  **flutter_local_notifications 17.2.4**, pinned in `pubspec.yaml`. That native
  path preserves the first date, advances by calendar days, and retains the
  plugin's cancellation, persistence and boot handling. Its mapper import and
  native channel field are internal APIs: recheck them and the scheduling
  regression tests before upgrading the plugin. This adapter is Android-only;
  the existing iOS/macOS repeat path still needs separate validation.
- On launch, saved contracts have their alarms replaced using the current
  scheduling rules, without permission prompts; completed contracts have their
  alarms cleared. This also replaces alarms from versions with the early-repeat
  bug. The background overdue summary waits until the next day's return time
  too; dashboard overdue status still starts as soon as the deadline passes.
- Android cannot deliver a reminder while the phone is powered off.
  `MissedNotificationBootReceiver` handles the restart: it immediately shows
  one-time reminders that elapsed while power was off, removes those consumed
  entries, advances daily overdue reminders to their next future day, then
  asks the notification plugin to restore every remaining alarm. It is in the
  plugin's Java package because this uses the same persisted notification
  records and display path as `flutter_local_notifications`. The app includes
  the plugin's Gson 2.8.9 dependency explicitly because the plugin does not
  export it to the app module. Test this after a phone shutdown when upgrading
  that dependency.
- The overdue-vehicle digest used to re-fire every time the app returned to
  the foreground — including the return caused by tapping the notification
  itself, which made it feel like it never stopped. It's now keyed by a
  signature of which contracts are overdue (`digestSignature`) and only
  alerts when that set actually changes; opening the app clears it instead.
- A notification tap can't navigate directly if the app is locked — the PIN
  guard would just bounce it to `/lock` and the destination would be lost.
  `pendingNotificationRoute` (a `ValueNotifier<String?>`) parks it, and
  `CarRentApp` replays it once `lockSignal` reports `unlocked`.

**Phone tests reported passing**: return/payment reminders, killed app,
restart after a missed deadline (delivery after 1-2 minutes), and notification
tap navigation. Recheck these on the release build and other phone brands.

### Contract signatures: on-device or returned PDF, no signing server

`ContractSigningService` prepares one permanent original PDF per contract.
Schema version 6 adds `contract_documents`, storing its SHA-256, the client
identity at preparation time, the frozen rental terms and the signed copy's
file name/hash. All PDFs and captured PNG signatures live in `MediaStore`,
so ZIP backup/restore includes them automatically.

The contract detail card supports two flows:
- **Signer sur ce téléphone**: preview the exact original, explicitly accept
  the terms, draw a signature, then stamp it in the original's named
  `client_signature` field. The saved result is a handwritten signature image,
  not a certified electronic signature. The timestamp is the phone's clock.
- **Envoyer au client pour signature**: share the original via the system
  share sheet. French instructions explain Adobe Acrobat Reader / Remplir et
  signer. Import the returned PDF, preview it and require operator review.
  Reject unreadable files, the unchanged original and a missing contract
  number. This is not automatic identity/signature verification. Store the
  returned bytes unchanged; the recorded time means receipt, not signing time.

An archived signed PDF cannot be overwritten. Preparing the first original
freezes rental terms in `ContractRepository.updateContract`; changed terms
require a new contract. Payment recording and closing still work and do not
rewrite the archived PDF. Related client/agency edits also leave it intact.
PDF fonts are bundled Roboto (Apache 2.0, assets/fonts/LICENSE.txt) for offline
use. Dates/times and amounts in the PDF use the saved contract values.

**Editing and deleting a contract** (`ContractEditScreen`, reached from a
"Modifier" icon on the contract detail page) exists for the case this section
doesn't cover: a contract created outright wrong (wrong car, wrong client,
wrong dates), not one whose terms need to change after signing. It's gated on
`ContractProgress.document == null` — no PDF prepared yet — so it never
collides with the frozen-terms rule above; `updateContract` itself enforces
that same check server-side, so the UI gate is a courtesy, not the only guard.
Reassigning the vehicle or chauffeur on an *active* contract through this
screen re-syncs their `rented`/`assigned` status the same way creating or
closing one does, and is refused (whole update rolled back) if the target is
already committed to a different active contract — mirroring the check
`insertContract` already made for a brand new one. `amountPaid` is shown but
not editable here; it's owned by the `payments` table via
`addPaymentAndUpdateContract`, not by this form. Deleting a contract (also
on the detail page, and by swiping it in the list) works at any status now,
not just `completed` — it always frees the vehicle/chauffeur if the contract
was active, so there was no technical reason to gate it. `ContractNotifier`'s
`updateContract`/`closeContract`/`deleteContract` propagate a failed operation
to the caller (mirroring `ClientNotifier.updateClient`); before this they
didn't, so a screen's own try/catch never fired — worth remembering if you add
another mutation there.

**"Clôturer le contrat" is reachable at any time — don't gate it on the
departure/return inspections.** A rewrite of the contract detail page once
made the close button wait on the departure inspection being done first,
hiding it entirely behind a single "État des lieux de départ" button until
then. That looked like reasonable sequencing (do the checklist, then close)
but was a regression: closing had always been a one-tap action, and this
silently took that away — the user caught it precisely because they'd relied
on it. `ContractDetailScreen._buildActionBar` now always offers Close
alongside whichever inspection step is next, and `test/contract_detail_controls_test.dart`
guards against reintroducing the hide-until-done version (it asserts on the
method's source directly, since the screen's own database calls make it
impractical to render whole in a widget test here).

Tests: `contract_signing_test.dart` covers capture/import, frozen terms,
unchanged original, corrupted files, v5 migration and restore after deleting
media. `client_signature_screen_test.dart` checks empty-signature prevention,
clear, and a narrow phone layout. `contract_repository_test.dart` covers the
edit-time vehicle/chauffeur reassignment and double-booking guards. Real
device signing/Adobe round-trip still needs manual validation.

### Profitability per vehicle: computed, not stored

`lib/domain/usecases/compute_vehicle_profitability.dart` turns a vehicle's
contracts and its `vehicle_expenses` rows (repairs, insurance premiums,
fines — a real table, schema v9, the first money-spent-on-a-vehicle tracking
this app had; before this only maintenance *dates* existed, never amounts)
into revenue, rental days, utilization %, and net profit. The use case itself
is pure — no repository, no database access — the same shape as
`BuildTodayOperations`: the provider layer (`vehicle_profitability_provider.dart`)
joins the contracts/vehicles already loaded elsewhere in the app with a fresh
read of expenses, maps them to plain domain entities, and only then calls the
use case. This avoids a second database read of contracts purely for this
report, and keeps the profit formula testable with plain objects
(`test/vehicle_profitability_test.dart`) instead of a fake repository.

**Utilization is rental days ÷ days since the vehicle was *added to the
app*, not since it was bought.** There is no purchase-date field. This was a
deliberate simplification, not an oversight — asked about explicitly, and a
purchase-date field was declined for now. A vehicle added to the app long
after it was actually bought will show an inflated utilization number; if
that starts mattering, the fix is a real acquisition-date field, not a
different formula.

Reachable two ways: a "Rentabilité" section on the vehicle's own detail page
(`VehicleDetailScreen`, with an "Ajouter une dépense" flow to record a cost),
and a fleet-wide ranked report at `/vehicles/profitability` (icon in the
Vehicles list header) showing every vehicle sorted by net profit — the "which
cars should I buy again or sell" view.

**Gated behind `LicenseFeature.profitability`** — both entry points, not just
the nav icon: `VehicleProfitabilityScreen` checks `licenseFeaturesSignal`
itself and shows a locked empty state if reached directly (a saved link, a
typed URL), the same way `ClientDetailScreen`'s history section does.
`test/vehicle_profitability_gate_test.dart` guards this; it was initially
shipped ungated by mistake and caught only when asked directly whether it
was — check a feature is actually gated before telling a customer it is.

### Licensing: RSA-4096, device-bound, offline

`lib/core/license/`. A licence is a base64-wrapped `{data, signature}`
envelope — name, expiry, device id — signed with RSA-4096 PSS/SHA-256 and
verified against the embedded public key. No server: `verifyLicense` runs
entirely on-device. `validateRuntime()` additionally detects clock rollback
(a hash of the last-run timestamp, so winding the system clock back to defeat
an expiry is caught). `scripts/generate_license.sh` mints one from the
private key; the app's licence screen shows the device id you paste in there.

**Licence-gated features, decided when the key is issued, not remotely.**
`LicenseData` also carries an optional `features` set (`lib/core/license/
license_features.dart` lists the known keys). This is what lets the same app
be sold with different feature sets per customer — set `--features` when
running `generate_license.sh`, nothing else changes. There is deliberately
**no server-side toggle**: changing what a customer has means issuing them a
new key, the same flow as a renewal, because a real-time remote switch would
mean this app phoning home, contradicting the "no server, fully offline"
choice above. `SplashScreen` populates `licenseFeaturesSignal` (a
`ValueNotifier<Set<String>>`) once at launch, and `LicenseManager.saveLicense`
updates it again the moment a new key is saved, so a renewal takes effect
without restarting the app. A screen gates a feature by reading that signal
directly (see `ClientDetailScreen`'s "Historique client" section) — no
Riverpod provider needed for what is a device-local capability flag, not app
data.

**`LicenseData.toMap()` must omit `features` entirely when it's empty — do
not "simplify" this to always emitting the key.** `verifyLicense` doesn't
check the signature against the bytes that were actually signed; it decodes
the licence into a typed `LicenseData` and re-derives the JSON from that
object's own `toMap()`. Every licence issued before this field existed was
signed over exactly three keys (`name`, `expiry`, `device_id`) with no
`features` key at all. If `toMap()` ever emits `"features":[]` unconditionally,
every one of those already-issued licences gets re-encoded with an extra key
during verification — different bytes than what was signed — and the
signature check fails. `generate_license.sh` mirrors the same rule: no
`--features` argument means no `features` key in the signed JSON, byte for
byte identical to the pre-this-feature format. `test/license_features_test.dart`
pins this with a real licence minted by the actual script against the actual
private key, at both a feature-less and a with-features call.

### Customer history: the first licence-gated feature

`ClientDetailScreen`'s "Historique client" section — total rentals, late
returns (both a completed contract returned after its due date, and an
active one already past it), unpaid balance, damage incidents — is a rollup
of data that already existed (contracts, inspections), computed the same
pure-use-case-joined-at-the-provider shape as vehicle profitability
(`compute_client_history.dart`, `client_history_provider.dart`). It renders
only when the active licence includes `LicenseFeature.customerHistory` —
the first real feature built on the gating above, not just plumbing.

The "Nécessite l'approbation du gérant" switch on the same screen is a
separate, **ungated** thing: a plain flag the operator sets on a client
themselves (new `requires_manager_approval` column, schema v10), not tied to
any licence. There's one operator and no roles to enforce it against (see
"Auth is a local PIN" above) — it's a reminder, not a permission wall, and it
does something concrete: `ContractFormScreen` shows a warning chip when a
flagged client is selected.

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
| Notifications | `flutter_local_notifications` 17.2.4 (pinned) + `timezone` + `flutter_timezone` |
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
   flutter analyze      # expect no issues
   flutter test         # expect all 301 passing
   ```
7. **Run it**:
   ```
   flutter run -d windows           # desktop
   flutter run -d <android-device>  # phone, USB debugging on
   ```

---

## 5. Repository

- `origin` → `github.com/MRX-Baiz/car-rent` — the active repo.
- The history is one logical change per commit with a "why" in the message.
  Keep doing that rather than reverting to giant commits.

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
  generate_license.sh       mint a licence key (needs the key from §1)
  generate_reset_token.sh   mint a PIN-reset token (needs the key from §1)
  make_icon_assets.py       launcher icon from source art
  make_notification_icon.py status-bar icon (monochrome silhouette)

test/                     301 tests; see §7
```

---

## 7. Testing

```
flutter analyze     # must report no issues before committing
flutter test         # 301 tests, all passing
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
- `notification_scheduling_test.dart` — Android channel regression for a
  three-minute contract: no time-only daily match, first overdue date tomorrow,
  normal return/payment alarms intact, cancellation, startup replacement,
  quiet hours, and no background digest immediately after the deadline.
- `vehicle_profitability_test.dart` — the profit formula against plain data:
  an in-progress rental counts days up to now not to a fictitious end date,
  expense categories sum independently, a vehicle added today doesn't divide
  by zero, one vehicle's expenses never leak into another's total.
- `vehicle_profitability_gate_test.dart` — reaching `/vehicles/profitability`
  directly without the licence feature shows the locked state, not real
  numbers; the nav icon being hidden is not itself a guard.
- `compute_client_history_test.dart` — same shape, for customer history: a
  completed contract returned late counts once, an active one already past
  its due date counts as currently late, unpaid balance only sums active
  contracts, a departure+return pair flagging the same contract counts as one
  damage incident, not two.
- `license_features_test.dart` — the licence backward-compatibility guard
  above, with a real licence minted by `generate_license.sh` against the real
  private key for both the feature-less and with-features cases.
- `database_fresh_install_test.dart` — guards schema drift between
  `_onCreate` and `_onUpgrade`; extended for `vehicle_expenses` and
  `requires_manager_approval` when those were added.

If you fix a bug, add the test that would have caught it before writing the
fix — that's the standard the existing suite was held to.

Widget tests that render screens must go through `test/helpers/french_app.dart`
(`frenchApp`): the app's copy is French, so a bare English `MaterialApp`
renders different strings and fails in ways that look like layout bugs.

---

## 8. Known gaps / open work

Roughly in the order they'd bite someone:

1. **Signing needs phone validation.** Both signing flows and automated
   regression tests are implemented. Test finger signing and the Adobe PDF
   share/sign/import round-trip on real hardware.
2. **Backup/restore is implemented and phone-tested.** Text, vehicle images,
   CIN and permis attachments restored successfully. Signing documents use
   the same media store; their restore is also covered by automated tests.
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
- **New screens are built on `AppPage`** (`lib/presentation/widgets/layout/
  app_page.dart`), not on a hand-made `Scaffold`. Pass a `title` and
  `children` and the page gets the app's look for free: the artwork backdrop
  that pans as you scroll, drifting gold glints, the scroll rail, an app bar
  that starts clear and turns white with a gold hairline, an animated title
  block, cards that slide in one by one, safe-area padding, and reduced-motion
  handling. Three styles, one per established look:
  - `AppPage(...)` — the default (Settings look, no photo). Almost every page.
  - `AppPage.hero(...)` — Settings in full: a pinned photo header that
    collapses into the bar. For a section's landing page.
  - `AppPage.home(...)` — Home: full-bleed artwork, the page supplies its own
    header as the first child, no auto-reveal.
  Long lazy lists pass `slivers:` instead of `children:`. `Settings` and the
  dashboard are themselves built on it, so it cannot drift from what users see.
  `test/app_page_adoption_test.dart` fails if a new screen builds its own
  `Scaffold`; the `_legacy` list in it is the backlog of older screens (forms,
  lock, licence…) still to migrate and may only shrink.
- Don't commit without being asked to. Don't push without being asked to.
